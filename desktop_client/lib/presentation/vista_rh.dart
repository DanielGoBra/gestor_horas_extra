import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../aplicacion/proveedores.dart';
import '../core/adaptativo.dart';
import '../core/iconografia.dart';
import '../core/tema.dart';
import '../data/api_error.dart';
import '../domain/entidades.dart';
import '../state/sesion_controller.dart';
import 'widgets/comun.dart';

class VistaRh extends ConsumerStatefulWidget {
  const VistaRh({super.key});

  @override
  ConsumerState<VistaRh> createState() => _VistaRhState();
}

class _VistaRhState extends ConsumerState<VistaRh> {
  final Set<int> _seleccionadas = {};
  List<Novedad>? _filas;
  List<UsuarioDirectorio>? _usuarios;
  List<Periodo>? _periodos;

  String? _area;
  int? _colaboradorId;
  String _estadoFiltro = 'PENDIENTE_APROBACION';
  DateTime? _desde, _hasta;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recargarTodo());
  }

  void _snack(String mensaje, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(mensaje),
      backgroundColor: error ? Theme.of(context).colorScheme.error : null,
    ));
  }

  Future<void> _recargarTodo() async {
    try {
      final rh = ref.read(rhRepoProvider);
      final resultados = await Future.wait([
        rh.usuarios(),
        rh.periodos(),
        _consultarBandeja(),
      ]);
      if (!mounted) return;
      setState(() {
        _usuarios = resultados[0] as List<UsuarioDirectorio>;
        _periodos = resultados[1] as List<Periodo>;
        _filas = resultados[2] as List<Novedad>;
        _cargando = false;
      });
    } on ApiError catch (e) {
      _snack(e.mensajeAmigable, error: true);
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<List<Novedad>> _consultarBandeja() async {
    return ref.read(rhRepoProvider).bandeja(
          desde: _desde,
          hasta: _hasta,
          area: (_area?.isEmpty ?? true) ? null : _area,
          colaboradorId: _colaboradorId,
          estado: _estadoFiltro.isEmpty ? null : _estadoFiltro,
        );
  }

  Future<void> _aplicarFiltros() async {
    setState(() => _cargando = true);
    try {
      final filas = await _consultarBandeja();
      if (!mounted) return;
      setState(() {
        _filas = filas;
        _seleccionadas.clear();
      });
    } on ApiError catch (e) {
      _snack(e.mensajeAmigable, error: true);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _aprobar(Novedad novedad) async {
    try {
      await ref.read(rhRepoProvider).aprobar(novedad.id);
      _snack('Solicitud #${novedad.id} aprobada. La operativa ya tiene la notificación y el tablero en Aprobado.');
      _aplicarFiltros();
    } on ApiError catch (e) {
      _snack(e.mensajeAmigable, error: true);
    }
  }

  Future<void> _rechazar(Novedad novedad) async {
    final controlador = TextEditingController();
    final observacion = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Rechazar solicitud #${novedad.id}'),
        content: TextField(
          controller: controlador,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Observación (obligatoria)',
            hintText: 'Explica el motivo para el colaborador',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controlador.text.trim()),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
    if (observacion == null) return;
    try {
      await ref.read(rhRepoProvider).rechazar(novedad.id, observacion);
      _snack('Solicitud #${novedad.id} rechazada.');
      _aplicarFiltros();
    } on ApiError catch (e) {
      _snack(e.mensajeAmigable, error: true);
    }
  }

  Future<void> _aprobarSeleccionadas() async {
    if (_seleccionadas.isEmpty) return;
    try {
      final ids = await ref.read(rhRepoProvider).aprobarMasivo(_seleccionadas.toList());
      _snack('${ids.length} solicitud(es) aprobadas en una transacción.');
      setState(() => _seleccionadas.clear());
      _aplicarFiltros();
    } on ApiError catch (e) {
      _snack(e.mensajeAmigable, error: true);
    }
  }

  Future<void> _exportarCsv() async {
    if ((_periodos ?? []).isEmpty) return;
    final periodo = await showDialog<Periodo>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Exportar consolidado de periodo'),
        children: [
          for (final p in _periodos!)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, p),
              child: Text('${p.etiqueta} (${p.estado})'),
            ),
        ],
      ),
    );
    if (periodo == null) return;
    try {
      final csv = await ref.read(rhRepoProvider).exportarCsv(periodo.id);
      final ruta = await getSaveLocation(
        suggestedName: 'consolidado_${periodo.etiqueta}.csv',
        acceptedTypeGroups: const [XTypeGroup(label: 'CSV', extensions: ['csv'])],
      );
      if (ruta == null) return;
      final archivo = XFile.fromData(utf8.encode(csv), mimeType: 'text/csv');
      await archivo.saveTo(ruta.path);
      _snack('CSV exportado a ${ruta.path}');
    } on ApiError catch (e) {
      _snack(e.mensajeAmigable, error: true);
    }
  }

  Future<void> _cerrarPeriodo(Periodo periodo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cerrar quincena ${periodo.etiqueta}'),
        content: const Text(
          'Las novedades APROBADAS del periodo quedarán congeladas como CERRADA_EN_NÓMINA y no admitirán cambios. ¿Continuar?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cerrar periodo')),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      final resultado = await ref.read(rhRepoProvider).cerrarPeriodo(periodo.id);
      _snack('Periodo cerrado: ${resultado['congeladas']} novedades congeladas.');
      _recargarTodo();
    } on ApiError catch (e) {
      _snack(e.mensajeAmigable, error: true);
    }
  }

  Future<void> _crearPeriodo() async {
    final etiqueta = TextEditingController();
    DateTime inicio = DateTime.now();
    DateTime fin = DateTime.now().add(const Duration(days: 14));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: const Text('Nuevo periodo quincenal'),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: etiqueta,
                    decoration: const InputDecoration(
                      labelText: 'Etiqueta',
                      hintText: '2026-Q2-AGOSTO',
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Fecha inicio'),
                    subtitle: Text(fmtFecha(inicio)),
                    trailing: const Icon(IconosInk.calendario),
                    onTap: () async {
                      final d = await elegirFecha(
                        ctx,
                        fechaInicial: inicio,
                        primera: DateTime(2024),
                        ultima: DateTime(2100),
                      );
                      if (d != null) setLocal(() => inicio = d);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Fecha fin'),
                    subtitle: Text(fmtFecha(fin)),
                    trailing: const Icon(IconosInk.calendario),
                    onTap: () async {
                      final d = await elegirFecha(
                        ctx,
                        fechaInicial: fin,
                        primera: DateTime(2024),
                        ultima: DateTime(2100),
                      );
                      if (d != null) setLocal(() => fin = d);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Crear')),
            ],
          ),
        );
      },
    );
    if (ok != true || etiqueta.text.trim().length < 4) {
      if (ok == true) _snack('La etiqueta debe tener al menos 4 caracteres.', error: true);
      return;
    }
    try {
      await ref.read(rhRepoProvider).crearPeriodo(etiqueta.text.trim(), inicio, fin);
      _snack('Periodo creado.');
      _recargarTodo();
    } on ApiError catch (e) {
      _snack(e.mensajeAmigable, error: true);
    }
  }

  Future<void> _nuevoSolicitante() async {
    final nombre = TextEditingController();
    final cargo = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Agregar solicitante'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nombre, decoration: const InputDecoration(labelText: 'Nombre')),
            const SizedBox(height: 8),
            TextField(controller: cargo, decoration: const InputDecoration(labelText: 'Cargo')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
        ],
      ),
    );
    if (ok != true || nombre.text.trim().length < 3) return;
    try {
      await ref.read(rhRepoProvider).crearSolicitante(nombre.text.trim(), cargo.text.trim());
      _snack('Solicitante agregado. Las operativas lo verán en el desplegable.');
    } on ApiError catch (e) {
      _snack(e.mensajeAmigable, error: true);
    }
  }

  Future<void> _editarVentanas() async {
    try {
      final actuales = await ref.read(catalogoRepoProvider).reglasLaborales();
      if (!mounted) return;
      final diurna = TextEditingController(text: actuales.etiquetaDiurna);
      final nocturna = TextEditingController(text: actuales.etiquetaNocturna);
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Ventanas diurna / nocturna'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: diurna,
                decoration: const InputDecoration(
                  labelText: 'Hora inicio diurna (HH:MM)',
                  hintText: '06:00',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nocturna,
                decoration: const InputDecoration(
                  labelText: 'Hora inicio nocturna (HH:MM)',
                  hintText: '21:00',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
          ],
        ),
      );
      if (ok != true) return;
      await ref.read(rhRepoProvider).actualizarReglas(diurna.text.trim(), nocturna.text.trim());
      _snack('Ventanas actualizadas. El recálculo de tramos usará los nuevos horarios.');
    } on ApiError catch (e) {
      _snack(e.mensajeAmigable, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = ref.watch(sesionProvider).usuario!;
    final puedeAprobar = usuario.puedeAprobar;
    final puedeExportar = usuario.puedeExportar;
    final puedeGestionar = usuario.puedeGestionar;
    final areas = <String>{
      for (final u in _usuarios ?? [])
        if (u.area.isNotEmpty) u.area,
    }.toList()
      ..sort();
    final pendientes = (_filas ?? []).where((n) => n.estado == 'PENDIENTE_APROBACION').length;
    final periodoAbierto = (_periodos ?? []).where((p) => !p.cerrado).firstOrNull;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, pagina) {
          final estrecho = pagina.maxWidth < Roturas.metricasApiladas;
          final tablaCompacta = pagina.maxWidth < Roturas.tablaCompacta;
          return Padding(
            padding: EdgeInsets.fromLTRB(estrecho ? 12 : 20, 12, estrecho ? 12 : 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                EncabezadoVista(
                  icono: puedeAprobar ? IconosInk.bandeja : IconosInk.csv,
                  titulo: puedeAprobar
                      ? 'Bandeja de operaciones'
                      : 'Reporte de horas extras',
                  subtitulo: puedeAprobar
                      ? 'Evalúe y apruebe o rechace las horas que ingresan las operativas. RRHH descarga el consolidado Excel.'
                      : 'Descargue el CSV del periodo. Replica el Excel de registro de horas extras en operaciones.',
                  acciones: [
                    if (puedeGestionar)
                      BotonClaro(onPressed: _editarVentanas, icono: IconosInk.ventanas, etiqueta: 'Ventanas'),
                    if (puedeGestionar)
                      BotonClaro(onPressed: _nuevoSolicitante, icono: IconosInk.solicitante, etiqueta: 'Solicitante'),
                    if (puedeExportar)
                      BotonClaro(onPressed: _exportarCsv, icono: IconosInk.csv, etiqueta: 'Excel / CSV'),
                  ],
                ),
                const SizedBox(height: 14),
                estrecho
                    ? Column(
                        children: [
                          TarjetaMetrica(
                            etiqueta: 'En esta vista',
                            valor: '${(_filas ?? []).length} solicitudes',
                            icono: IconosInk.bandejaVacia,
                            acento: Paleta.pantone300,
                          ),
                          const SizedBox(height: 8),
                          TarjetaMetrica(
                            etiqueta: 'En revisión',
                            valor: '$pendientes',
                            icono: IconosInk.revision,
                            acento: Paleta.pantone130,
                          ),
                          const SizedBox(height: 8),
                          TarjetaMetrica(
                            etiqueta: 'Periodo abierto',
                            valor: periodoAbierto?.etiqueta ?? 'Ninguno',
                            icono: IconosInk.periodoAbierto,
                            acento: Paleta.pantone362,
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: TarjetaMetrica(
                              etiqueta: 'En esta vista',
                              valor: '${(_filas ?? []).length} solicitudes',
                              icono: IconosInk.bandejaVacia,
                              acento: Paleta.pantone300,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TarjetaMetrica(
                              etiqueta: 'En revisión',
                              valor: '$pendientes',
                              icono: IconosInk.revision,
                              acento: Paleta.pantone130,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TarjetaMetrica(
                              etiqueta: 'Periodo abierto',
                              valor: periodoAbierto?.etiqueta ?? 'Ninguno',
                              icono: IconosInk.periodoAbierto,
                              acento: Paleta.pantone362,
                            ),
                          ),
                        ],
                      ),
                const SizedBox(height: 12),
            Vidrio(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  ListaOpciones<String>(
                    etiqueta: 'Estado',
                    valor: _estadoFiltro,
                    ancho: estrecho ? (pagina.maxWidth - 56).clamp(180, 640) : 180,
                    opciones: const [
                      OpcionLista('PENDIENTE_APROBACION', 'En revisión'),
                      OpcionLista('APROBADA', 'Aprobado'),
                      OpcionLista('RECHAZADA', 'Rechazado'),
                      OpcionLista('CERRADA_EN_NOMINA', 'En nómina'),
                      OpcionLista('', 'Todos'),
                    ],
                    onChanged: (v) => setState(() => _estadoFiltro = v ?? ''),
                  ),
                  ListaOpciones<String>(
                    etiqueta: 'Área',
                    valor: _area,
                    ancho: estrecho ? (pagina.maxWidth - 56).clamp(180, 640) : 180,
                    opciones: [
                      const OpcionLista(null, 'Todas'),
                      for (final a in areas) OpcionLista(a, a),
                    ],
                    onChanged: (v) => setState(() => _area = v),
                  ),
                  ListaOpciones<int>(
                    etiqueta: 'Colaborador',
                    valor: _colaboradorId,
                    ancho: estrecho ? (pagina.maxWidth - 56).clamp(180, 640) : 260,
                    opciones: [
                      const OpcionLista(null, 'Todos'),
                      for (final u in _usuarios ?? [])
                        OpcionLista(u.id, u.nombre),
                    ],
                    onChanged: (v) => setState(() => _colaboradorId = v),
                  ),
                  SizedBox(
                    width: 140,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const EtiquetaCampo('Desde'),
                        CajaEntrada(
                          onTap: () async {
                            final nueva = await elegirFecha(
                              context,
                              fechaInicial: _desde ?? DateTime.now(),
                              primera: DateTime(2024),
                              ultima: DateTime(2100),
                            );
                            if (nueva != null) setState(() => _desde = nueva);
                          },
                          child: Text(
                            _desde == null ? '—' : fmtFecha(_desde!),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Paleta.tinta,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 140,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const EtiquetaCampo('Hasta'),
                        CajaEntrada(
                          onTap: () async {
                            final nueva = await elegirFecha(
                              context,
                              fechaInicial: _hasta ?? DateTime.now(),
                              primera: DateTime(2024),
                              ultima: DateTime(2100),
                            );
                            if (nueva != null) setState(() => _hasta = nueva);
                          },
                          child: Text(
                            _hasta == null ? '—' : fmtFecha(_hasta!),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Paleta.tinta,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _aplicarFiltros,
                    icon: const Icon(IconosInk.filtrar),
                    label: const Text('Aplicar'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (puedeAprobar)
                  FilledButton.icon(
                    onPressed: _seleccionadas.isEmpty ? null : _aprobarSeleccionadas,
                    icon: const Icon(IconosInk.aprobarVarias),
                    label: Text('Aprobar seleccionadas (${_seleccionadas.length})'),
                  ),
                if (puedeGestionar)
                  OutlinedButton.icon(
                    onPressed: _crearPeriodo,
                    icon: const Icon(IconosInk.nuevo),
                    label: const Text('Nuevo periodo'),
                  ),
                if (puedeGestionar && _periodos != null)
                  for (final p in _periodos!.take(3))
                    p.cerrado
                        ? Chip(label: Text('${p.etiqueta} · cerrado'))
                        : ActionChip(
                            label: Text('Cerrar ${p.etiqueta}'),
                            avatar: const Icon(IconosInk.periodoCerrado, size: 16),
                            onPressed: () => _cerrarPeriodo(p),
                          ),
                if (!puedeGestionar && _periodos != null)
                  for (final p in _periodos!.take(3))
                    Chip(label: Text('${p.etiqueta} · ${p.cerrado ? 'cerrado' : 'abierto'}')),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Vidrio(
                expandir: true,
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: _cargando
                    ? const Center(child: CircularProgressIndicator())
                    : (_filas ?? []).isEmpty
                        ? const EstadoVacio(
                            icono: IconosInk.sinFiltro,
                            titulo: 'Sin resultados',
                            detalle: 'Prueba otro estado, área o rango de fechas.',
                          )
                        : _ListaSolicitudesRh(
                            filas: _filas!,
                            compacta: tablaCompacta,
                            mostrarAcciones: puedeAprobar,
                            seleccionadas: _seleccionadas,
                            onToggle: (n, v) => setState(() {
                              v ? _seleccionadas.add(n.id) : _seleccionadas.remove(n.id);
                            }),
                            onAprobar: _aprobar,
                            onRechazar: _rechazar,
                          ),
              ),
            ),
          ],
            ),
          );
        },
      ),
    );
  }
}

class _ListaSolicitudesRh extends StatelessWidget {
  final List<Novedad> filas;
  final bool compacta;
  final bool mostrarAcciones;
  final Set<int> seleccionadas;
  final void Function(Novedad novedad, bool seleccionada) onToggle;
  final ValueChanged<Novedad> onAprobar;
  final ValueChanged<Novedad> onRechazar;

  const _ListaSolicitudesRh({
    required this.filas,
    required this.compacta,
    required this.mostrarAcciones,
    required this.seleccionadas,
    required this.onToggle,
    required this.onAprobar,
    required this.onRechazar,
  });

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      thumbVisibility: true,
      child: ListView.separated(
        padding: const EdgeInsets.only(right: 8, bottom: 8),
        itemCount: compacta ? filas.length : filas.length + 1,
        separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0x33005DB4)),
        itemBuilder: (context, i) {
          if (!compacta && i == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
              child: _FilaBandeja.encabezado(mostrarAcciones: mostrarAcciones),
            );
          }
          final n = filas[compacta ? i : i - 1];
          if (compacta) {
            return _TarjetaSolicitudRh(
              novedad: n,
              mostrarAcciones: mostrarAcciones,
              seleccionada: seleccionadas.contains(n.id),
              onToggle: (v) => onToggle(n, v),
              onAprobar: () => onAprobar(n),
              onRechazar: () => onRechazar(n),
            );
          }
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: _FilaBandeja(
              novedad: n,
              mostrarAcciones: mostrarAcciones,
              seleccionada: seleccionadas.contains(n.id),
              onToggle: (v) => onToggle(n, v),
              onAprobar: () => onAprobar(n),
              onRechazar: () => onRechazar(n),
            ),
          );
        },
      ),
    );
  }
}

class _FilaBandeja extends StatelessWidget {
  final Novedad? novedad;
  final bool seleccionada;
  final bool mostrarAcciones;
  final ValueChanged<bool>? onToggle;
  final VoidCallback? onAprobar;
  final VoidCallback? onRechazar;

  const _FilaBandeja({
    required Novedad this.novedad,
    required this.seleccionada,
    required this.mostrarAcciones,
    required this.onToggle,
    required this.onAprobar,
    required this.onRechazar,
  });

  const _FilaBandeja.encabezado({this.mostrarAcciones = true})
      : novedad = null,
        seleccionada = false,
        onToggle = null,
        onAprobar = null,
        onRechazar = null;

  bool get _esEncabezado => novedad == null;

  @override
  Widget build(BuildContext context) {
    final n = novedad;
    final estilo = TextStyle(
      fontWeight: _esEncabezado ? FontWeight.w800 : FontWeight.w700,
      fontSize: _esEncabezado ? 12 : 13,
      color: Paleta.tinta,
    );
    final actividad = n == null
        ? ''
        : [
            n.justificacion,
            if ((n.observacionAdicional ?? '').isNotEmpty) n.observacionAdicional!,
          ].join(' · ');
    final horario = n == null || n.tramos.isEmpty
        ? ''
        : '${hhmm(n.tramos.first.inicioDt)} – ${hhmm(n.tramos.last.finDt)}';

    Widget celda(String texto, {int flex = 1, int maxLines = 2}) {
      return Expanded(
        flex: flex,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            texto,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: estilo,
          ),
        ),
      );
    }

    Widget separador() => Container(
          width: 1,
          height: 38,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          color: const Color(0x4D005DB4),
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (mostrarAcciones)
          SizedBox(
            width: 44,
            child: _esEncabezado
                ? Text('Sel.', style: estilo)
                : Checkbox(
                    value: seleccionada,
                    onChanged: n!.estado == 'PENDIENTE_APROBACION'
                        ? (v) => onToggle!(v ?? false)
                        : null,
                  ),
          ),
        SizedBox(
          width: 40,
          child: Text(_esEncabezado ? '#' : '${n!.id}', style: estilo),
        ),
        separador(),
        celda(_esEncabezado ? 'Colaborador' : (n!.colaboradorNombre ?? n.colaboradorCodigo ?? ''), flex: 2),
        separador(),
        celda(_esEncabezado ? 'Quién solicita' : (n!.solicitanteNombre ?? '—'), flex: 2),
        separador(),
        SizedBox(
          width: 96,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(_esEncabezado ? 'Fecha' : fmtFecha(n!.fechaTrabajo), style: estilo),
          ),
        ),
        separador(),
        SizedBox(
          width: 118,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(_esEncabezado ? 'Horario' : horario, style: estilo),
          ),
        ),
        separador(),
        SizedBox(
          width: 58,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(_esEncabezado ? 'Total' : fmtHoras(n!.totalMinutos), style: estilo),
          ),
        ),
        separador(),
        celda(_esEncabezado ? 'Actividad / observaciones' : actividad, flex: 3, maxLines: 4),
        separador(),
        SizedBox(
          width: 120,
          child: _esEncabezado
              ? Text('Estado', style: estilo)
              : Align(alignment: Alignment.centerLeft, child: ChipEstado(estado: n!.estado)),
        ),
        if (mostrarAcciones) ...[
          separador(),
          SizedBox(
            width: 100,
            child: _esEncabezado
                ? Text('Acciones', style: estilo)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Aprobar',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        icon: Icon(IconosInk.aprobar, color: const Color(0xFF1B5E20)),
                        onPressed: n!.estado == 'PENDIENTE_APROBACION' ? onAprobar : null,
                      ),
                      IconButton(
                        tooltip: 'Rechazar con observación',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        icon: Icon(IconosInk.rechazar, color: Paleta.rechazo),
                        onPressed: n.estado == 'PENDIENTE_APROBACION' ? onRechazar : null,
                      ),
                    ],
                  ),
          ),
        ],
      ],
    );
  }
}

class _TarjetaSolicitudRh extends StatelessWidget {
  final Novedad novedad;
  final bool seleccionada;
  final bool mostrarAcciones;
  final ValueChanged<bool> onToggle;
  final VoidCallback onAprobar;
  final VoidCallback onRechazar;

  const _TarjetaSolicitudRh({
    required this.novedad,
    required this.seleccionada,
    required this.mostrarAcciones,
    required this.onToggle,
    required this.onAprobar,
    required this.onRechazar,
  });

  @override
  Widget build(BuildContext context) {
    final n = novedad;
    final horario = n.tramos.isEmpty
        ? '—'
        : '${hhmm(n.tramos.first.inicioDt)} – ${hhmm(n.tramos.last.finDt)}';
    final actividad = [
      n.justificacion,
      if ((n.observacionAdicional ?? '').isNotEmpty) n.observacionAdicional!,
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (mostrarAcciones)
                  Checkbox(
                    value: seleccionada,
                    onChanged: n.estado == 'PENDIENTE_APROBACION'
                        ? (v) => onToggle(v ?? false)
                        : null,
                  ),
                Expanded(
                  child: Text(
                    n.colaboradorNombre ?? n.colaboradorCodigo ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: Paleta.tinta),
                  ),
                ),
                ChipEstado(estado: n.estado),
              ],
            ),
            Text(
              '#${n.id} · ${fmtFecha(n.fechaTrabajo)} · $horario · ${fmtHoras(n.totalMinutos)}',
              style: const TextStyle(fontWeight: FontWeight.w700, color: Paleta.tinta),
            ),
            const SizedBox(height: 4),
            Text(
              'Quién solicita: ${n.solicitanteNombre ?? '—'}',
              style: const TextStyle(fontWeight: FontWeight.w600, color: Paleta.tinta),
            ),
            const SizedBox(height: 6),
            Text(
              actividad,
              style: const TextStyle(fontWeight: FontWeight.w700, color: Paleta.tinta),
            ),
            const SizedBox(height: 4),
            if (mostrarAcciones)
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Aprobar',
                      icon: const Icon(IconosInk.aprobar, color: Color(0xFF1B5E20)),
                      onPressed: n.estado == 'PENDIENTE_APROBACION' ? onAprobar : null,
                    ),
                    IconButton(
                      tooltip: 'Rechazar con observación',
                      icon: const Icon(IconosInk.rechazar, color: Paleta.rechazo),
                      onPressed: n.estado == 'PENDIENTE_APROBACION' ? onRechazar : null,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
