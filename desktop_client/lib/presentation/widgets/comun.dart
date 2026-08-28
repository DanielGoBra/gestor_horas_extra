import 'package:flutter/material.dart';

import '../../core/iconografia.dart';
import '../../core/tema.dart';
import '../../domain/motor_reglas.dart';

class ChipEstado extends StatelessWidget {
  final String estado;
  const ChipEstado({super.key, required this.estado});

  @override
  Widget build(BuildContext context) {
    final color = TemaApp.colorEstado(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: TemaApp.fondoEstado(estado),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color, width: 1.6),
      ),
      child: Text(
        TemaApp.etiquetaEstado(estado),
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class EncabezadoVista extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String? subtitulo;
  final List<Widget> acciones;

  const EncabezadoVista({
    super.key,
    required this.icono,
    required this.titulo,
    this.subtitulo,
    this.acciones = const [],
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final accionesAbajo = !constraints.hasBoundedWidth || constraints.maxWidth < 820;
        final tituloBloque = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icono, color: Paleta.pantone300),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  if (subtitulo != null)
                    Text(
                      subtitulo!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            height: 1.4,
                            shadows: const [
                              Shadow(color: Colors.black26, blurRadius: 6),
                            ],
                          ),
                    ),
                ],
              ),
            ),
          ],
        );
        final botones = acciones.isEmpty
            ? const SizedBox.shrink()
            : Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: acciones,
              );
        if (accionesAbajo) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              tituloBloque,
              if (acciones.isNotEmpty) ...[
                const SizedBox(height: 10),
                botones,
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: tituloBloque),
            if (acciones.isNotEmpty) ...[
              const SizedBox(width: 12),
              botones,
            ],
          ],
        );
      },
    );
  }
}

class TarjetaMetrica extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final IconData icono;
  final Color acento;

  const TarjetaMetrica({
    super.key,
    required this.etiqueta,
    required this.valor,
    required this.icono,
    required this.acento,
  });

  @override
  Widget build(BuildContext context) {
    return Vidrio(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: acento.withValues(alpha: 0.22),
            foregroundColor: Paleta.tinta,
            child: Icon(icono, color: acento, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  etiqueta,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Paleta.tinta,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                Text(
                  valor,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Paleta.tinta,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EstadoVacio extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String detalle;

  const EstadoVacio({
    super.key,
    required this.icono,
    required this.titulo,
    required this.detalle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 40, color: Paleta.pantone300.withValues(alpha: 0.7)),
          const SizedBox(height: 10),
          Text(titulo, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            detalle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class BarraTramos extends StatelessWidget {
  final List<TramoCalculado> tramos;
  const BarraTramos({super.key, required this.tramos});

  @override
  Widget build(BuildContext context) {
    final total = totalMinutos(tramos);
    if (total == 0) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 12,
        child: Row(
          children: [
            for (final t in tramos)
              Expanded(
                flex: t.minutos.clamp(1, 100000),
                child: ColoredBox(color: TemaApp.colorTipoHora(t.tipoHora.codigo)),
              ),
          ],
        ),
      ),
    );
  }
}

class BotonClaro extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icono;
  final String etiqueta;

  const BotonClaro({
    super.key,
    required this.onPressed,
    required this.icono,
    required this.etiqueta,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: Paleta.tinta,
        backgroundColor: Colors.white,
        disabledForegroundColor: const Color(0xFF5A6B7A),
        side: const BorderSide(color: Paleta.tinta, width: 1.6),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
      onPressed: onPressed,
      icon: Icon(icono, size: 18, color: Paleta.tinta),
      label: Text(etiqueta),
    );
  }
}

class EtiquetaCampo extends StatelessWidget {
  final String texto;
  final bool obligatorio;

  const EtiquetaCampo(this.texto, {super.key, this.obligatorio = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(
        TextSpan(
          text: texto,
          style: const TextStyle(
            color: Paleta.tinta,
            fontWeight: FontWeight.w800,
            fontSize: 13,
            height: 1.25,
          ),
          children: [
            if (obligatorio)
              const TextSpan(
                text: ' *',
                style: TextStyle(color: Paleta.rechazo, fontWeight: FontWeight.w800),
              ),
          ],
        ),
      ),
    );
  }
}

class CajaEntrada extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double? alto;

  const CajaEntrada({super.key, required this.child, this.onTap, this.alto});

  @override
  Widget build(BuildContext context) {
    final caja = Container(
      height: alto ?? 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFB7C4D4)),
      ),
      alignment: Alignment.centerLeft,
      child: child,
    );
    if (onTap == null) return caja;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: caja,
      ),
    );
  }
}

class OpcionLista<T> {
  final T? valor;
  final String texto;
  const OpcionLista(this.valor, this.texto);
}

class ListaOpciones<T> extends StatelessWidget {
  final String? etiqueta;
  final T? valor;
  final List<OpcionLista<T>> opciones;
  final ValueChanged<T?> onChanged;
  final double ancho;
  final bool compacto;
  final bool embebido;

  const ListaOpciones({
    super.key,
    this.etiqueta,
    required this.valor,
    required this.opciones,
    required this.onChanged,
    this.ancho = 200,
    this.compacto = false,
    this.embebido = false,
  });

  String get _texto {
    for (final o in opciones) {
      if (o.valor == valor) return o.texto;
    }
    return opciones.isEmpty ? '—' : opciones.first.texto;
  }

  @override
  Widget build(BuildContext context) {
    final menu = MenuAnchor(
      consumeOutsideTap: true,
      alignmentOffset: const Offset(0, 4),
      clipBehavior: Clip.antiAlias,
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(Colors.white),
        elevation: const WidgetStatePropertyAll(14),
        shadowColor: WidgetStatePropertyAll(Colors.black.withValues(alpha: 0.28)),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 4)),
        minimumSize: WidgetStatePropertyAll(Size(ancho, 0)),
        maximumSize: WidgetStatePropertyAll(Size(ancho, 260)),
        visualDensity: VisualDensity.compact,
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFFB7C4D4)),
          ),
        ),
      ),
      builder: (context, controller, _) {
        void alternar() => controller.isOpen ? controller.close() : controller.open();
        final fila = Row(
          children: [
            Expanded(
              child: Text(
                _texto,
                overflow: TextOverflow.ellipsis,
                textAlign: embebido ? TextAlign.center : TextAlign.start,
                style: const TextStyle(
                  color: Paleta.tinta,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            Icon(
              controller.isOpen ? IconosInk.caretArriba : IconosInk.caretAbajo,
              color: Paleta.pantone300,
              size: embebido ? 18 : 22,
            ),
          ],
        );
        if (embebido) {
          return InkWell(
            onTap: alternar,
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(height: 36, child: fila),
          );
        }
        return CajaEntrada(
          alto: compacto ? 40 : 44,
          onTap: alternar,
          child: fila,
        );
      },
      menuChildren: [
        for (final o in opciones)
          MenuItemButton(
            onPressed: () => onChanged(o.valor),
            style: ButtonStyle(
              minimumSize: WidgetStatePropertyAll(Size(ancho, 40)),
              maximumSize: WidgetStatePropertyAll(Size(ancho, 40)),
              padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
              backgroundColor: WidgetStatePropertyAll(
                o.valor == valor ? const Color(0xFFE8F1FB) : Colors.white,
              ),
            ),
            child: Text(
              o.texto,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Paleta.tinta,
                fontWeight: o.valor == valor ? FontWeight.w800 : FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
      ],
    );

    if (etiqueta == null) return SizedBox(width: ancho, child: menu);
    return SizedBox(
      width: ancho,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          EtiquetaCampo(etiqueta!),
          menu,
        ],
      ),
    );
  }
}

String fmtFecha(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String fmtHoras(int minutos) =>
    '${(minutos / 60).toStringAsFixed(minutos % 60 == 0 ? 0 : 1)} h';

String hhmm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

Future<DateTime?> elegirFecha(
  BuildContext context, {
  required DateTime fechaInicial,
  required DateTime primera,
  required DateTime ultima,
}) {
  return showDatePicker(
    context: context,
    locale: const Locale('es', 'CO'),
    initialDate: fechaInicial,
    firstDate: primera,
    lastDate: ultima,
    helpText: 'Seleccionar fecha',
    cancelText: 'Cancelar',
    confirmText: 'Aceptar',
    fieldLabelText: 'Fecha',
    fieldHintText: 'dd/mm/aaaa',
  );
}
