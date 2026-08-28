import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/adaptativo.dart';
import '../core/iconografia.dart';
import '../core/tema.dart';
import '../state/sesion_controller.dart';
import 'vista_operativa.dart';
import 'vista_rh.dart';

class Shell extends ConsumerStatefulWidget {
  const Shell({super.key});

  @override
  ConsumerState<Shell> createState() => _ShellState();
}

class _ShellState extends ConsumerState<Shell> {
  int _indice = 0;

  @override
  Widget build(BuildContext context) {
    final sesion = ref.watch(sesionProvider);
    final usuario = sesion.usuario!;

    final secciones = <_Seccion>[
      if (usuario.puedeRegistrar)
        const _Seccion(
          icono: IconosInk.horas,
          titulo: 'Mis horas extra',
          vista: VistaOperativa(),
        ),
      if (usuario.veBandeja)
        _Seccion(
          icono: usuario.puedeAprobar ? IconosInk.bandeja : IconosInk.csv,
          titulo: usuario.puedeAprobar ? 'Bandeja de operaciones' : 'Reporte RRHH',
          vista: const VistaRh(),
        ),
    ];
    if (secciones.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: Text('Este usuario no tiene módulos asignados.')),
      );
    }
    final indice = _indice.clamp(0, secciones.length - 1);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final navCompacta = constraints.maxWidth < Roturas.navCompacta;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(navCompacta ? 8 : 12, 12, 0, 12),
                child: SizedBox(
                  width: navCompacta ? 76 : 236,
                  child: Vidrio(
                    expandir: true,
                    padding: EdgeInsets.fromLTRB(
                      navCompacta ? 8 : 14,
                      18,
                      navCompacta ? 8 : 14,
                      14,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: navCompacta ? 36 : 40,
                              height: navCompacta ? 36 : 40,
                              decoration: BoxDecoration(
                                color: Paleta.pantone375,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                'INK',
                                style: TextStyle(
                                  color: Paleta.pantone300,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            if (!navCompacta) ...[
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'INKLUSIVA',
                                      style: TextStyle(
                                        color: Paleta.tinta,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
                                    ),
                                    Text(
                                      'Horas extras',
                                      style: TextStyle(color: Paleta.tintaSuave, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 22),
                        for (var i = 0; i < secciones.length; i++)
                          _DestinoNav(
                            icono: secciones[i].icono,
                            titulo: secciones[i].titulo,
                            seleccionado: i == indice,
                            compacto: navCompacta,
                            onTap: () => setState(() => _indice = i),
                          ),
                        const Spacer(),
                        Container(
                          padding: EdgeInsets.all(navCompacta ? 6 : 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: navCompacta
                              ? Column(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: Paleta.pantone375,
                                      foregroundColor: Paleta.pantone300,
                                      child: Text(
                                        usuario.codigo.substring(0, 2),
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Cerrar sesión',
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(IconosInk.salir, size: 18, color: Paleta.tinta),
                                      onPressed: () => ref.read(sesionProvider.notifier).salir(),
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: Paleta.pantone375,
                                      foregroundColor: Paleta.pantone300,
                                      child: Text(
                                        usuario.codigo.substring(0, 2),
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            usuario.nombre,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12,
                                              color: Paleta.tinta,
                                            ),
                                          ),
                                          Text(
                                            '${usuario.area} · ${usuario.rol}',
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: Paleta.tinta,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Cerrar sesión',
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(IconosInk.salir, size: 18, color: Paleta.tinta),
                                      onPressed: () => ref.read(sesionProvider.notifier).salir(),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(child: secciones[indice].vista),
            ],
          );
        },
      ),
    );
  }
}

class _DestinoNav extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final bool seleccionado;
  final bool compacto;
  final VoidCallback onTap;

  const _DestinoNav({
    required this.icono,
    required this.titulo,
    required this.seleccionado,
    required this.onTap,
    this.compacto = false,
  });

  @override
  Widget build(BuildContext context) {
    final contenido = Padding(
      padding: EdgeInsets.symmetric(horizontal: compacto ? 8 : 10, vertical: 11),
      child: Row(
        mainAxisAlignment: compacto ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          Icon(
            icono,
            size: 20,
            color: seleccionado ? Paleta.pantone300 : Paleta.tinta,
          ),
          if (!compacto) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                titulo,
                style: TextStyle(
                  fontWeight: seleccionado ? FontWeight.w800 : FontWeight.w600,
                  color: Paleta.tinta,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: seleccionado
            ? Paleta.pantone375.withValues(alpha: 0.55)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: compacto ? Tooltip(message: titulo, child: contenido) : contenido,
        ),
      ),
    );
  }
}

class _Seccion {
  final IconData icono;
  final String titulo;
  final Widget vista;

  const _Seccion({required this.icono, required this.titulo, required this.vista});
}
