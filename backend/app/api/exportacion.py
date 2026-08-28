"""Exportación CSV compatible con el Excel de operaciones INKLUSIVA."""
from __future__ import annotations

from datetime import datetime

from app.dominio.entidades import EstadoNovedad
from app.infra.modelos import SolicitudHorasExtraORM, TramoDetalleORM, UsuarioORM

CABECERAS_EXCEL = [
    "Id",
    "Hora de inicio",
    "Hora de finalización",
    "Correo electrónico",
    "Nombre",
    "Fecha en la que realizo las horas extras",
    "Seleccione la hora de inicio",
    "Seleccione el minuto de inicio",
    "Franja horario de inicio",
    "Seleccione la hora de finalización",
    "Seleccione el minuto de finalización",
    "Franja horario de finalización",
    "Total horas extras",
    "Cantidad horas extras diurnas",
    "Cantidad horas extras nocturnas",
    "Quien autoriza las horas extras",
    "Observaciones",
    "Fecha de Pago",
    "Cantidad horas extra",
]


def _partes_12h(momento: datetime) -> tuple[int, str, str]:
    minuto = f"{momento.minute:02d}"
    hora = momento.hour
    if hora == 0:
        return 12, minuto, "AM"
    if hora < 12:
        return hora, minuto, "AM"
    if hora == 12:
        return 12, minuto, "PM"
    return hora - 12, minuto, "PM"


def _horas_decimal(minutos: int) -> str:
    if minutos <= 0:
        return ""
    valor = minutos / 60
    if valor == int(valor):
        return str(int(valor))
    texto = f"{valor:.2f}".rstrip("0").rstrip(".")
    return texto


def _observaciones(solicitud: SolicitudHorasExtraORM) -> str:
    partes = [solicitud.justificacion or ""]
    extra = (solicitud.observacion_adicional or "").strip()
    if extra:
        partes.append(extra)
    return " | ".join(p.strip() for p in partes if p.strip())


def fila_excel(
    solicitud: SolicitudHorasExtraORM,
    usuario: UsuarioORM,
    tramos: list[TramoDetalleORM],
) -> list:
    inicio = solicitud.inicio_dt
    fin = solicitud.fin_dt
    h_ini, m_ini, f_ini = _partes_12h(inicio)
    h_fin, m_fin, f_fin = _partes_12h(fin)
    diurnas = sum(t.minutos for t in tramos if t.tipo_hora == "EXTRA_DIURNA")
    nocturnas = sum(t.minutos for t in tramos if t.tipo_hora == "EXTRA_NOCTURNA")
    total = sum(t.minutos for t in tramos) or int((fin - inicio).total_seconds() // 60)
    fecha_pago = ""
    if solicitud.fecha_pago is not None:
        fecha_pago = solicitud.fecha_pago.strftime("%d/%m/%Y")
    elif solicitud.estado == EstadoNovedad.CERRADA_EN_NOMINA.value:
        fecha_pago = solicitud.actualizada_en.strftime("%d/%m/%Y") if solicitud.actualizada_en else ""
    return [
        solicitud.id,
        inicio.strftime("%d/%m/%Y %I:%M:%S %p"),
        fin.strftime("%d/%m/%Y %I:%M:%S %p"),
        usuario.correo or "",
        usuario.nombre,
        solicitud.fecha_trabajo.strftime("%d/%m/%Y"),
        h_ini,
        m_ini,
        f_ini,
        h_fin,
        m_fin,
        f_fin,
        _horas_decimal(total),
        _horas_decimal(diurnas),
        _horas_decimal(nocturnas),
        solicitud.solicitante.nombre if solicitud.solicitante else "",
        _observaciones(solicitud),
        fecha_pago,
        _horas_decimal(total),
    ]
