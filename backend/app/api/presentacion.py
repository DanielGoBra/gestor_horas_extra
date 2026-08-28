"""Serializadores de salida (dominio -> esquemas API)."""
from __future__ import annotations

from app.api.esquemas import NovedadOut, TramoOut
from app.dominio.entidades import RegistroNovedad
from app.infra.modelos import UsuarioORM


def a_tramo_out(tramo) -> TramoOut:
    return TramoOut(
        inicio_dt=tramo.inicio_dt,
        fin_dt=tramo.fin_dt,
        tipo_hora=tramo.tipo_hora.value if hasattr(tramo.tipo_hora, "value") else tramo.tipo_hora,
        minutos=tramo.minutos,
    )


def a_novedad_out(
    novedad: RegistroNovedad,
    colaborador: UsuarioORM | None = None,
) -> NovedadOut:
    total = sum(t.minutos for t in novedad.tramos)
    return NovedadOut(
        id=novedad.id,
        colaborador_id=novedad.colaborador_id,
        colaborador_codigo=colaborador.codigo if colaborador else None,
        colaborador_nombre=colaborador.nombre if colaborador else None,
        area=colaborador.area if colaborador else None,
        solicitante_id=novedad.solicitante_id,
        solicitante_nombre=novedad.solicitante_nombre,
        fecha_trabajo=novedad.fecha_trabajo,
        justificacion=novedad.justificacion,
        observacion_adicional=novedad.observacion_adicional,
        estado=novedad.estado.value,
        observacion_rh=novedad.observacion_rh,
        fecha_pago=novedad.fecha_pago if hasattr(novedad, "fecha_pago") else None,
        total_minutos=total,
        tramos=[a_tramo_out(t) for t in sorted(novedad.tramos, key=lambda x: x.inicio_dt)],
    )
