import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../aplicacion/enviar_solicitud.dart';
import '../aplicacion/proveedores.dart';
import '../core/iconografia.dart';
import '../core/tema.dart';
import '../data/api_error.dart';
import '../domain/entidades.dart';
import '../domain/motor_reglas.dart';
import 'widgets/comun.dart';

class VistaOperativa extends ConsumerStatefulWidget {
  const VistaOperativa({super.key});

  @override
  ConsumerState<VistaOperativa> createState() => _VistaOperativaState();
}

class _VistaOperativaState extends ConsumerState<VistaOperativa> {
  DateTime _fecha = DateTime.now();
  int _horaInicio = 18, _minInicio = 0;
  int _horaFin = 20, _minFin = 30;
  final _justificacion = TextEditingController();
  final _observacion = TextEditingController();
  List<TramoCalculado>? _vistaPrevia;
  List<String> _avisos = [];
  bool _procesando = false;
  bool _cargando = true;
  List<Solicitante> _solicitantes = [];
  int? _solicitanteId;
  ParametrosReglas _reglas = const ParametrosReglas();
  List<Novedad>? _historial;
  List<Notificacion> _avisosRh = [];
  Timer? _relojAvisos;

  @override
  void dispose() {
    _relojAvisos?.cancel();
    _justificacion.dispose();
    _observacion.dispose();
    super.dispose();
  }

  Future<void> _cargarHistorial() async {
    try {
      final horas = ref.read(horasRepoProvider);
      final catalogo = ref.read(catalogoRepoProvider);
      final resultados = await Future.wait([
        horas.mias(),
        catalogo.solicitantes(),
        catalogo.reglasLaborales(),
        horas.notificaciones(soloNoLeidas: true),
      ]);
      if (!mounted) return;
      setState(() {
        _historial = resultados[0] as List<Novedad>;
        _solicitantes = resultados[1] as List<Solicitante>;
        _reglas = resultados[2] as ParametrosReglas;
        _avisosRh = resultados[3] as List<Notificacion>;
        _solicitanteId ??= _solicitantes.isEmpty ? null : _solicitantes.first.id;
        _cargando = false;
      });
      _previsualizarLocal();
    } on ApiError catch (e) {
      if (mounted) setState(() => _cargando = false);
      _snack(e.mensajeAmigable, error: true);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarHistorial());
    _relojAvisos = Timer.periodic(const Duration(seconds: 12), (_) {
      if (!mounted) return;
      _cargarHistorial();
    });
  }

  void _snack(String mensaje, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(mensaje),
      backgroundColor: error ? Theme.of(context).colorScheme.error : null,
    ));
  }

  void _previsualizarLocal() {
    try {
      final tramos = calcularTramos(
        _fecha,
        _horaInicio,
        _minInicio,
        _horaFin,
        _minFin,
        params: _reglas,
      );
      setState(() {
        _vistaPrevia = tramos;
        _avisos = [];
        final total = totalMinutos(tramos);
        if (total > _reglas.topeMinutosDiarios) {
          _avisos.add(
            'Supera el tope legal de ${(_reglas.topeMinutosDiarios / 60).toStringAsFixed(0)} h diarias; requerirá justificación RH.',
          );
        }
      });
    } on IntervaloInvalido catch (e) {
      setState(() {
        _vistaPrevia = null;
        _avisos = [e.mensaje];
      });
    }
  }

  Future<void> _enviarSolicitud() async {
    if (_solicitanteId == null) {
      _snack('Selecciona quién solicitó las horas extra.', error: true);
      return;
    }
    if (_justificacion.text.trim().length < 5) {
      _snack('Describe la justificación (mínimo 5 caracteres).', error: true);
      return;
    }
    final extra = _observacion.text.trim();
    final solicitud = SolicitudPendiente(
      _fecha,
      '${_horaInicio.toString().padLeft(2, '0')}:${_minInicio.toString().padLeft(2, '0')}',
      '${_horaFin.toString().padLeft(2, '0')}:${_minFin.toString().padLeft(2, '0')}',
      _justificacion.text.trim(),
      _solicitanteId!,
      observacionAdicional: extra.isEmpty ? null : extra,
    );
    setState(() => _procesando = true);
    try {
      final resultado = await ref.read(enviarSolicitudProvider).ejecutar(solicitud);
      if (resultado == ResultadoEnvio.enCola) {
        _snack('Sin conexión: solicitud guardada en cola local.', error: true);
      } else {
        _snack('Registro enviado. Queda En revisión para que el jefe de operaciones lo apruebe.');
      }
      _limpiarFormulario();
      _cargarHistorial();
    } on ApiError catch (e) {
      _snack(e.mensajeAmigable, error: true);
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _reintentarCola() async {
    final enviadas = await ref.read(colaLocalProvider).reintentar(ref.read(horasRepoProvider));
    _snack(enviadas > 0
        ? '$enviadas solicitud(es) sincronizada(s).'
        : 'El servidor sigue inaccesible.');
    _cargarHistorial();
  }

  void _limpiarFormulario() {
    _justificacion.clear();
    _observacion.clear();
    if (mounted) {
      setState(() {});
      _previsualizarLocal();
    }
  }

  Future<void> _reconocerAvisos() async {
    try {
      await ref.read(horasRepoProvider).marcarNotificacionesLeidas();
      if (mounted) setState(() => _avisosRh = []);
    } on ApiError {
      if (mounted) setState(() => _avisosRh = []);
    }
  }

  Future<void> _cancelar(Novedad novedad) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar solicitud'),
        content: Text('¿Eliminar la solicitud del ${fmtFecha(novedad.fechaTrabajo)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sí, cancelar')),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await ref.read(horasRepoProvider).cancelar(novedad.id);
      _snack('Solicitud eliminada.');
      _cargarHistorial();
    } on ApiError catch (e) {
      _snack(e.mensajeAmigable, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FutureBuilder<List<SolicitudPendiente>>(
        future: ref.read(colaLocalProvider).pendientes(),
        builder: (context, snapshot) {
          final pendientes = snapshot.data?.length ?? 0;
          if (pendientes == 0) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            icon: const Icon(IconosInk.sincronizar),
            label: Text('$pendientes en cola'),
            tooltip: 'Reintentar envío al servidor',
            onPressed: _reintentarCola,
          );
        },
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EncabezadoVista(
              icono: IconosInk.horas,
              titulo: 'Registro de horas extras',
              subtitulo: 'INKLUSIVA S.A.S. · Operaciones. Solo se reconocen horas autorizadas y registradas.',
            ),
            const SizedBox(height: 16),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compacto = constraints.maxWidth < 980;
                  final formulario = _FormularioRegistro(
                    expandir: !compacto,
                    fecha: _fecha,
                    horaInicio: _horaInicio,
                    minInicio: _minInicio,
                    horaFin: _horaFin,
                    minFin: _minFin,
                    justificacion: _justificacion,
                    observacion: _observacion,
                    solicitantes: _solicitantes,
                    solicitanteId: _solicitanteId,
                    reglas: _reglas,
                    procesando: _procesando,
                    onFecha: (f) {
                      setState(() => _fecha = f);
                      _previsualizarLocal();
                    },
                    onInicio: (h, m) {
                      setState(() {
                        _horaInicio = h;
                        _minInicio = m;
                      });
                      _previsualizarLocal();
                    },
                    onFin: (h, m) {
                      setState(() {
                        _horaFin = h;
                        _minFin = m;
                      });
                      _previsualizarLocal();
                    },
                    onTurno: (ini, fin) {
                      setState(() {
                        _horaInicio = ini ~/ 60;
                        _minInicio = ini % 60;
                        _horaFin = fin ~/ 60;
                        _minFin = fin % 60;
                      });
                      _previsualizarLocal();
                    },
                    onSolicitante: (v) => setState(() => _solicitanteId = v),
                    onEnviar: _enviarSolicitud,
                  );
                  final preview = _PanelPrevia(
                    tramos: _vistaPrevia,
                    avisos: _avisos,
                    compacto: compacto,
                  );
                  final historial = _PanelHistorial(
                    cargando: _cargando,
                    historial: _historial,
                    avisos: _avisosRh,
                    onCancelar: _cancelar,
                    onCerrarAvisos: _reconocerAvisos,
                    compacto: compacto,
                  );

                  if (compacto) {
                    return ListView(
                      children: [
                        formulario,
                        const SizedBox(height: 14),
                        preview,
                        const SizedBox(height: 14),
                        historial,
                      ],
                    );
                  }
                  return Column(
                    children: [
                      Expanded(
                        flex: 11,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(flex: 11, child: formulario),
                            const SizedBox(width: 14),
                            Expanded(flex: 9, child: preview),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Expanded(flex: 10, child: historial),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormularioRegistro extends StatelessWidget {
  final DateTime fecha;
  final int horaInicio, minInicio, horaFin, minFin;
  final TextEditingController justificacion;
  final TextEditingController observacion;
  final List<Solicitante> solicitantes;
  final int? solicitanteId;
  final ParametrosReglas reglas;
  final bool procesando;
  final bool expandir;
  final ValueChanged<DateTime> onFecha;
  final void Function(int, int) onInicio;
  final void Function(int, int) onFin;
  final void Function(int, int) onTurno;
  final ValueChanged<int?> onSolicitante;
  final VoidCallback onEnviar;

  const _FormularioRegistro({
    required this.fecha,
    required this.horaInicio,
    required this.minInicio,
    required this.horaFin,
    required this.minFin,
    required this.justificacion,
    required this.observacion,
    required this.solicitantes,
    required this.solicitanteId,
    required this.reglas,
    required this.procesando,
    required this.expandir,
    required this.onFecha,
    required this.onInicio,
    required this.onFin,
    required this.onTurno,
    required this.onSolicitante,
    required this.onEnviar,
  });

  String _totalEtiqueta() {
    final ini = horaInicio * 60 + minInicio;
    var fin = horaFin * 60 + minFin;
    if (fin <= ini) fin += 24 * 60;
    final mins = fin - ini;
    return '${mins ~/ 60}:${(mins % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Vidrio(
      expandir: expandir,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Registro de horas extras',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Debe diligenciarse a más tardar dos (2) días hábiles después de realizadas. '
              'Requieren autorización previa del Jefe de Operaciones o un Gerente.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Paleta.tinta,
                    height: 1.45,
                    fontSize: 13,
                  ),
            ),
            const SizedBox(height: 14),
            _SelectorFecha(fecha: fecha, onChanged: onFecha),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                _SelectorHora(
                  etiqueta: 'Hora de inicio',
                  horas: horaInicio,
                  minutos: minInicio,
                  onChanged: onInicio,
                ),
                _SelectorHora(
                  etiqueta: 'Hora de final',
                  horas: horaFin,
                  minutos: minFin,
                  onChanged: onFin,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Ejemplo: 8:00 pm. Cantidad total: ${_totalEtiqueta()}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Paleta.tinta,
                  ),
            ),
            const SizedBox(height: 14),
            const EtiquetaCampo('Actividad realizada', obligatorio: true),
            TextField(
              controller: justificacion,
              maxLines: 3,
              style: const TextStyle(fontWeight: FontWeight.w600, color: Paleta.tinta),
              decoration: const InputDecoration(
                hintText: 'Breve descripción de la actividad o tarea realizada.',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            const EtiquetaCampo('Quién solicita el apoyo (jefe comercial)', obligatorio: true),
            for (final s in solicitantes)
              RadioListTile<int>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: s.id,
                groupValue: solicitanteId,
                title: Text(
                  s.nombre,
                  style: const TextStyle(fontSize: 13, color: Paleta.tinta, fontWeight: FontWeight.w700),
                ),
                subtitle: s.cargo.isEmpty
                    ? null
                    : Text(
                        s.cargo,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Paleta.tinta),
                      ),
                onChanged: onSolicitante,
              ),
            const SizedBox(height: 8),
            const EtiquetaCampo('Observación adicional'),
            TextField(
              controller: observacion,
              maxLines: 2,
              style: const TextStyle(fontWeight: FontWeight.w600, color: Paleta.tinta),
              decoration: const InputDecoration(
                hintText: 'Cualquier comentario adicional relevante.',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: procesando ? null : onEnviar,
                icon: const Icon(IconosInk.enviar),
                label: Text(procesando ? 'Enviando…' : 'Enviar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelPrevia extends StatelessWidget {
  final List<TramoCalculado>? tramos;
  final List<String> avisos;
  final bool compacto;
  const _PanelPrevia({required this.tramos, required this.avisos, required this.compacto});

  @override
  Widget build(BuildContext context) {
    return Vidrio(
      expandir: !compacto,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Vista previa de recargos', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Se actualiza al cambiar fecha u horario.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Paleta.tinta,
                ),
          ),
          const SizedBox(height: 16),
          if (tramos == null)
            _envolver(
              compacto: compacto,
              child: const EstadoVacio(
                icono: IconosInk.calcular,
                titulo: 'Sin intervalo válido',
                detalle: 'Ajusta la hora de entrada y salida para ver el desglose.',
              ),
            )
          else ...[
            BarraTramos(tramos: tramos!),
            const SizedBox(height: 14),
            _envolver(
              compacto: compacto,
              child: ListView(
                shrinkWrap: compacto,
                physics: compacto ? const NeverScrollableScrollPhysics() : null,
                children: [
                  for (final t in tramos!)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: TemaApp.colorTipoHora(t.tipoHora.codigo),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                t.tipoHora.etiqueta,
                                style: const TextStyle(fontWeight: FontWeight.w700, color: Paleta.tinta),
                              ),
                            ),
                              Text(
                                t.rango,
                                style: const TextStyle(
                                  color: Paleta.tinta,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            const SizedBox(width: 12),
                            Text(
                              fmtHoras(t.minutos),
                              style: const TextStyle(fontWeight: FontWeight.w800, color: Paleta.tinta),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 20),
            Text(
              'Total: ${totalMinutos(tramos!)} min (${fmtHoras(totalMinutos(tramos!))})',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
          for (final aviso in avisos)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  Icon(IconosInk.aviso, size: 18, color: Theme.of(context).colorScheme.error),
                  const SizedBox(width: 6),
                  Expanded(child: Text(aviso, style: const TextStyle(fontWeight: FontWeight.w700))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static Widget _envolver({required bool compacto, required Widget child}) {
    if (compacto) return child;
    return Expanded(child: child);
  }
}

class _PanelHistorial extends StatelessWidget {
  final bool cargando;
  final List<Novedad>? historial;
  final List<Notificacion> avisos;
  final ValueChanged<Novedad> onCancelar;
  final VoidCallback onCerrarAvisos;
  final bool compacto;

  const _PanelHistorial({
    required this.cargando,
    required this.historial,
    required this.avisos,
    required this.onCancelar,
    required this.onCerrarAvisos,
    required this.compacto,
  });

  @override
  Widget build(BuildContext context) {
    return Vidrio(
      expandir: !compacto,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Mi tablero', style: Theme.of(context).textTheme.titleMedium),
          if (avisos.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final aviso in avisos)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Paleta.pantone375.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Paleta.pantone362),
                ),
                child: Row(
                  children: [
                    const Icon(IconosInk.campana, color: Paleta.pantone300),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(aviso.titulo, style: const TextStyle(fontWeight: FontWeight.w800, color: Paleta.tinta)),
                          Text(aviso.mensaje, style: const TextStyle(fontSize: 12, color: Paleta.tinta)),
                        ],
                      ),
                    ),
                    TextButton(onPressed: onCerrarAvisos, child: const Text('Entendido')),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 10),
          if (cargando)
            _cuerpo(compacto, const Center(child: CircularProgressIndicator()))
          else if ((historial ?? []).isEmpty)
            _cuerpo(
              compacto,
              const EstadoVacio(
                icono: IconosInk.bandejaVacia,
                titulo: 'Sin solicitudes aún',
                detalle: 'Cuando envíes una jornada extraordinaria aparecerá aquí con su estado.',
              ),
            )
          else
            _cuerpo(
              compacto,
              ListView.separated(
                shrinkWrap: compacto,
                physics: compacto ? const NeverScrollableScrollPhysics() : null,
                itemCount: historial!.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final n = historial![i];
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fmtFecha(n.fechaTrabajo),
                                style: const TextStyle(fontWeight: FontWeight.w800, color: Paleta.tinta),
                              ),
                              Text(
                                '${n.solicitanteNombre ?? '—'} · ${n.justificacion}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: Paleta.tintaSuave),
                              ),
                              if (n.observacionRh != null && n.observacionRh!.isNotEmpty)
                                Text(
                                  'RH: ${n.observacionRh}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, color: Paleta.tinta),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(fmtHoras(n.totalMinutos), style: const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(width: 10),
                        ChipEstado(estado: n.estado),
                        const SizedBox(width: 4),
                        n.editable
                            ? IconButton(
                                tooltip: 'Cancelar solicitud',
                                icon: const Icon(IconosInk.eliminar),
                                onPressed: () => onCancelar(n),
                              )
                            : const Padding(
                                padding: EdgeInsets.all(8),
                                child: Icon(IconosInk.periodoCerrado, size: 18, color: Paleta.tinta),
                              ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  static Widget _cuerpo(bool compacto, Widget child) {
    if (compacto) return child;
    return Expanded(child: child);
  }
}

class _SelectorFecha extends StatelessWidget {
  final DateTime fecha;
  final ValueChanged<DateTime> onChanged;

  const _SelectorFecha({required this.fecha, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EtiquetaCampo('Fecha en la que realizó las horas extras', obligatorio: true),
        CajaEntrada(
          onTap: () async {
            final nueva = await elegirFecha(
              context,
              fechaInicial: fecha,
              primera: DateTime.now().subtract(const Duration(days: 90)),
              ultima: DateTime.now().add(const Duration(days: 90)),
            );
            if (nueva != null) onChanged(nueva);
          },
          child: Row(
            children: [
              const Icon(IconosInk.calendario, color: Paleta.pantone300, size: 20),
              const SizedBox(width: 8),
              Text(
                fmtFecha(fecha),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Paleta.tinta,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SelectorHora extends StatelessWidget {
  final String etiqueta;
  final int horas;
  final int minutos;
  final void Function(int, int) onChanged;

  const _SelectorHora({
    required this.etiqueta,
    required this.horas,
    required this.minutos,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hora12 = horas % 12 == 0 ? 12 : horas % 12;
    final esPm = horas >= 12;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EtiquetaCampo(etiqueta, obligatorio: true),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.98),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFB7C4D4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListaOpciones<int>(
                valor: hora12,
                ancho: 78,
                embebido: true,
                opciones: [for (var h = 1; h <= 12; h++) OpcionLista(h, '$h')],
                onChanged: (v) => onChanged(_a24(v ?? 12, esPm), minutos),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  ':',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Paleta.tinta),
                ),
              ),
              ListaOpciones<int>(
                valor: minutos == 30 ? 30 : 0,
                ancho: 78,
                embebido: true,
                opciones: const [OpcionLista(0, '00'), OpcionLista(30, '30')],
                onChanged: (v) => onChanged(horas, v ?? 0),
              ),
              Container(
                width: 1,
                height: 28,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: const Color(0xFFD0D7DE),
              ),
              ListaOpciones<bool>(
                valor: esPm,
                ancho: 86,
                embebido: true,
                opciones: const [OpcionLista(false, 'AM'), OpcionLista(true, 'PM')],
                onChanged: (v) => onChanged(_a24(hora12, v ?? false), minutos),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static int _a24(int hora12, bool pm) {
    if (hora12 == 12) return pm ? 12 : 0;
    return pm ? hora12 + 12 : hora12;
  }
}
