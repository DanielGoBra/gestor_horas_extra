"""Repositorios: acceso a datos y mapeo ORM <-> Dominio."""
from __future__ import annotations

from datetime import date, datetime, time as hora_dia, timedelta
from typing import Iterable

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.dominio.entidades import (
    EstadoNovedad,
    RegistroNovedad,
    TramoHorario,
)
from app.dominio.motor_reglas import ParametrosReglas
from app.infra.modelos import (
    CorteNominaORM,
    FestivoORM,
    NotificacionORM,
    ParametroNominaORM,
    SolicitanteORM,
    SolicitudHorasExtraORM,
    TramoDetalleORM,
    UsuarioORM,
)


def festivos_como_conjunto(sesion: Session, desde: date, hasta: date) -> frozenset[date]:
    filas = sesion.scalars(
        select(FestivoORM.fecha).where(FestivoORM.fecha.between(desde, hasta))
    ).all()
    return frozenset(filas)


def usuario_por_codigo(sesion: Session, codigo: str) -> UsuarioORM | None:
    return sesion.scalar(select(UsuarioORM).where(UsuarioORM.codigo == codigo))


def usuario_por_correo(sesion: Session, correo: str) -> UsuarioORM | None:
    return sesion.scalar(select(UsuarioORM).where(func.lower(UsuarioORM.correo) == correo.lower()))


def usuario_por_login(sesion: Session, identificador: str) -> UsuarioORM | None:
    crudo = identificador.strip()
    hallado = usuario_por_codigo(sesion, crudo) or usuario_por_codigo(sesion, crudo.upper())
    if hallado is None and "@" in crudo:
        hallado = usuario_por_correo(sesion, crudo)
    return hallado


def usuario_por_id(sesion: Session, usuario_id: int) -> UsuarioORM | None:
    return sesion.get(UsuarioORM, usuario_id)


def usuarios_todos(sesion: Session) -> list[UsuarioORM]:
    return list(sesion.scalars(select(UsuarioORM).order_by(UsuarioORM.codigo)).all())


def existe_solapamiento(
    sesion: Session,
    colaborador_id: int,
    ini_dt: datetime,
    fin_dt: datetime,
    excluir_solicitud_id: int | None = None,
) -> bool:
    condicion = (
        SolicitudHorasExtraORM.colaborador_id == colaborador_id,
        SolicitudHorasExtraORM.estado != EstadoNovedad.RECHAZADA.value,
        SolicitudHorasExtraORM.inicio_dt < fin_dt,
        SolicitudHorasExtraORM.fin_dt > ini_dt,
    )
    if excluir_solicitud_id is not None:
        condicion = (*condicion, SolicitudHorasExtraORM.id != excluir_solicitud_id)
    return sesion.scalar(select(func.count()).select_from(SolicitudHorasExtraORM).where(*condicion)) > 0


def minutos_comprometidos_por_fecha(
    sesion: Session, colaborador_id: int, desde: datetime, hasta: datetime
) -> dict[date, int]:
    """Minutos en tramos vivos (no RECHAZADA) agrupados por fecha de inicio del tramo."""
    filas = sesion.execute(
        select(TramoDetalleORM.inicio_dt, TramoDetalleORM.minutos)
        .join(SolicitudHorasExtraORM, TramoDetalleORM.solicitud_id == SolicitudHorasExtraORM.id)
        .where(
            SolicitudHorasExtraORM.colaborador_id == colaborador_id,
            SolicitudHorasExtraORM.estado != EstadoNovedad.RECHAZADA.value,
            TramoDetalleORM.inicio_dt >= desde,
            TramoDetalleORM.inicio_dt < hasta,
        )
    ).all()
    totales: dict[date, int] = {}
    for inicio_dt, minutos in filas:
        totales[inicio_dt.date()] = totales.get(inicio_dt.date(), 0) + minutos
    return totales


def _a_dominio(fila: SolicitudHorasExtraORM) -> RegistroNovedad:
    return RegistroNovedad(
        id=fila.id,
        colaborador_id=fila.colaborador_id,
        fecha_trabajo=fila.fecha_trabajo,
        justificacion=fila.justificacion,
        observacion_adicional=fila.observacion_adicional,
        estado=EstadoNovedad(fila.estado),
        observacion_rh=fila.observacion_rh,
        aprobada_por=fila.aprobada_por,
        solicitante_id=fila.solicitante_id,
        solicitante_nombre=fila.solicitante.nombre if fila.solicitante else None,
        creada_en=fila.creada_en,
        actualizada_en=fila.actualizada_en,
        fecha_pago=fila.fecha_pago,
        tramos=[
            TramoHorario(inicio_dt=t.inicio_dt, fin_dt=t.fin_dt, tipo_hora=t.tipo_hora)
            for t in sorted(fila.tramos, key=lambda x: x.inicio_dt)
        ],
    )


def guardar_novedad(sesion: Session, novedad: RegistroNovedad) -> RegistroNovedad:
    if novedad.id is None:
        fila = SolicitudHorasExtraORM(
            colaborador_id=novedad.colaborador_id,
            solicitante_id=novedad.solicitante_id,
            fecha_trabajo=novedad.fecha_trabajo,
            inicio_dt=min(t.inicio_dt for t in novedad.tramos),
            fin_dt=max(t.fin_dt for t in novedad.tramos),
            justificacion=novedad.justificacion,
            observacion_adicional=novedad.observacion_adicional,
            estado=novedad.estado.value,
            observacion_rh=novedad.observacion_rh,
            fecha_pago=novedad.fecha_pago,
            aprobada_por=novedad.aprobada_por,
            creada_en=novedad.creada_en or datetime.utcnow(),
            actualizada_en=novedad.actualizada_en or datetime.utcnow(),
        )
        sesion.add(fila)
        sesion.flush()
        for t in novedad.tramos:
            sesion.add(
                TramoDetalleORM(
                    solicitud_id=fila.id,
                    inicio_dt=t.inicio_dt,
                    fin_dt=t.fin_dt,
                    tipo_hora=t.tipo_hora.value,
                    minutos=t.minutos,
                )
            )
        novedad.id = fila.id
        return novedad

    fila = sesion.get(SolicitudHorasExtraORM, novedad.id)
    if fila is None:
        raise LookupError("NO_ENCONTRADO")
    fila.justificacion = novedad.justificacion
    fila.observacion_adicional = novedad.observacion_adicional
    fila.estado = novedad.estado.value
    fila.observacion_rh = novedad.observacion_rh
    fila.fecha_pago = novedad.fecha_pago
    fila.aprobada_por = novedad.aprobada_por
    fila.actualizada_en = novedad.actualizada_en or datetime.utcnow()
    fila.tramos.clear()
    sesion.flush()
    for t in novedad.tramos:
        sesion.add(
            TramoDetalleORM(
                solicitud_id=fila.id,
                inicio_dt=t.inicio_dt,
                fin_dt=t.fin_dt,
                tipo_hora=t.tipo_hora.value,
                minutos=t.minutos,
            )
        )
    sesion.flush()
    return novedad


def novedad_por_id(sesion: Session, novedad_id: int) -> RegistroNovedad | None:
    fila = sesion.get(SolicitudHorasExtraORM, novedad_id)
    return _a_dominio(fila) if fila else None


def fila_novedad(sesion: Session, novedad_id: int) -> SolicitudHorasExtraORM | None:
    return sesion.get(SolicitudHorasExtraORM, novedad_id)


def novedades_propias(
    sesion: Session, colaborador_id: int, limite: int = 200
) -> list[RegistroNovedad]:
    filas = sesion.scalars(
        select(SolicitudHorasExtraORM)
        .where(SolicitudHorasExtraORM.colaborador_id == colaborador_id)
        .order_by(SolicitudHorasExtraORM.fecha_trabajo.desc(), SolicitudHorasExtraORM.id.desc())
        .limit(limite)
    ).unique().all()
    return [_a_dominio(f) for f in filas]


def bandeja_rh(
    sesion: Session,
    estados: Iterable[str] | None = None,
    desde: date | None = None,
    hasta: date | None = None,
    area: str | None = None,
    colaborador_id: int | None = None,
) -> list[tuple[RegistroNovedad, UsuarioORM]]:
    consulta = (
        select(SolicitudHorasExtraORM, UsuarioORM)
        .join(UsuarioORM, SolicitudHorasExtraORM.colaborador_id == UsuarioORM.id)
        .order_by(SolicitudHorasExtraORM.fecha_trabajo.asc(), SolicitudHorasExtraORM.id.asc())
    )
    condiciones = []
    if estados:
        condiciones.append(SolicitudHorasExtraORM.estado.in_(list(estados)))
    if desde:
        condiciones.append(SolicitudHorasExtraORM.fecha_trabajo >= desde)
    if hasta:
        condiciones.append(SolicitudHorasExtraORM.fecha_trabajo <= hasta)
    if area:
        condiciones.append(UsuarioORM.area == area)
    if colaborador_id:
        condiciones.append(SolicitudHorasExtraORM.colaborador_id == colaborador_id)
    if condiciones:
        consulta = consulta.where(*condiciones)
    filas = sesion.execute(consulta).unique().all()
    return [(_a_dominio(sol), usu) for sol, usu in filas]


def periodo_que_cubre(sesion: Session, fecha: date) -> CorteNominaORM | None:
    return sesion.scalar(
        select(CorteNominaORM).where(
            CorteNominaORM.fecha_inicio <= fecha,
            CorteNominaORM.fecha_fin >= fecha,
        )
    )


def periodo_por_etiqueta(sesion: Session, etiqueta: str) -> CorteNominaORM | None:
    return sesion.scalar(select(CorteNominaORM).where(CorteNominaORM.etiqueta == etiqueta))


def periodos_todos(sesion: Session) -> list[CorteNominaORM]:
    return list(sesion.scalars(select(CorteNominaORM).order_by(CorteNominaORM.fecha_inicio.desc())).all())


def consolidado_periodo(
    sesion: Session, desde: date, hasta: date
) -> list[tuple[SolicitudHorasExtraORM, TramoDetalleORM, UsuarioORM]]:
    return list(
        sesion.execute(
            select(SolicitudHorasExtraORM, TramoDetalleORM, UsuarioORM)
            .join(TramoDetalleORM, TramoDetalleORM.solicitud_id == SolicitudHorasExtraORM.id)
            .join(UsuarioORM, SolicitudHorasExtraORM.colaborador_id == UsuarioORM.id)
            .where(
                SolicitudHorasExtraORM.fecha_trabajo >= desde,
                SolicitudHorasExtraORM.fecha_trabajo <= hasta,
                SolicitudHorasExtraORM.estado.in_(
                    [EstadoNovedad.APROBADA.value, EstadoNovedad.CERRADA_EN_NOMINA.value]
                ),
            )
            .order_by(UsuarioORM.codigo, TramoDetalleORM.inicio_dt)
        ).unique().all()
    )


def solicitudes_para_excel(
    sesion: Session, desde: date, hasta: date
) -> list[tuple[SolicitudHorasExtraORM, UsuarioORM]]:
    return list(
        sesion.execute(
            select(SolicitudHorasExtraORM, UsuarioORM)
            .join(UsuarioORM, SolicitudHorasExtraORM.colaborador_id == UsuarioORM.id)
            .where(
                SolicitudHorasExtraORM.fecha_trabajo >= desde,
                SolicitudHorasExtraORM.fecha_trabajo <= hasta,
            )
            .order_by(SolicitudHorasExtraORM.fecha_trabajo.desc(), SolicitudHorasExtraORM.id.desc())
        ).unique().all()
    )


def lunes_de_semana(f: date) -> date:
    return f - timedelta(days=f.weekday())


def crear_periodo(
    sesion: Session, etiqueta: str, fecha_inicio: date, fecha_fin: date
) -> CorteNominaORM:
    periodo = CorteNominaORM(
        etiqueta=etiqueta,
        fecha_inicio=fecha_inicio,
        fecha_fin=fecha_fin,
        estado="ABIERTO",
    )
    sesion.add(periodo)
    sesion.flush()
    return periodo


def periodo_por_id(sesion: Session, periodo_id: int) -> CorteNominaORM | None:
    return sesion.get(CorteNominaORM, periodo_id)


def congelar_aprobadas_del_periodo(
    sesion: Session, periodo: CorteNominaORM, ahora: datetime
) -> list[int]:
    filas = sesion.scalars(
        select(SolicitudHorasExtraORM).where(
            SolicitudHorasExtraORM.fecha_trabajo >= periodo.fecha_inicio,
            SolicitudHorasExtraORM.fecha_trabajo <= periodo.fecha_fin,
            SolicitudHorasExtraORM.estado == EstadoNovedad.APROBADA.value,
        )
    ).unique().all()
    congeladas: list[int] = []
    for fila in filas:
        fila.estado = EstadoNovedad.CERRADA_EN_NOMINA.value
        fila.actualizada_en = ahora
        if fila.fecha_pago is None:
            fila.fecha_pago = periodo.fecha_fin
        congeladas.append(fila.id)
    sesion.flush()
    return congeladas


def solicitantes_activos(sesion: Session) -> list[SolicitanteORM]:
    return list(
        sesion.scalars(
            select(SolicitanteORM).where(SolicitanteORM.activo.is_(True)).order_by(SolicitanteORM.nombre)
        ).all()
    )


def solicitante_por_id(sesion: Session, solicitante_id: int) -> SolicitanteORM | None:
    return sesion.get(SolicitanteORM, solicitante_id)


def crear_solicitante(sesion: Session, nombre: str, cargo: str) -> SolicitanteORM:
    fila = SolicitanteORM(nombre=nombre.strip(), cargo=cargo.strip(), activo=True)
    sesion.add(fila)
    sesion.flush()
    return fila


def _parse_hora(valor: str, defecto: hora_dia) -> hora_dia:
    try:
        hh, mm = valor.split(":")
        return hora_dia(int(hh), int(mm))
    except (ValueError, AttributeError):
        return defecto


def parametros_vigentes(sesion: Session) -> ParametrosReglas:
    filas = sesion.scalars(select(ParametroNominaORM)).all()
    mapa = {f.clave: f.valor for f in filas}
    return ParametrosReglas(
        inicio_diurna=_parse_hora(mapa.get("inicio_diurna", "06:00"), hora_dia(6, 0)),
        fin_diurna=_parse_hora(mapa.get("inicio_nocturna", "21:00"), hora_dia(21, 0)),
    )


def guardar_parametros(sesion: Session, inicio_diurna: str, inicio_nocturna: str) -> None:
    pares = {"inicio_diurna": inicio_diurna, "inicio_nocturna": inicio_nocturna}
    for clave, valor in pares.items():
        fila = sesion.get(ParametroNominaORM, clave)
        if fila is None:
            sesion.add(ParametroNominaORM(clave=clave, valor=valor))
        else:
            fila.valor = valor
    sesion.flush()


def crear_notificacion(
    sesion: Session,
    usuario_id: int,
    titulo: str,
    mensaje: str,
    solicitud_id: int | None = None,
) -> NotificacionORM:
    fila = NotificacionORM(
        usuario_id=usuario_id,
        solicitud_id=solicitud_id,
        titulo=titulo,
        mensaje=mensaje,
        leida=False,
        creada_en=datetime.utcnow(),
    )
    sesion.add(fila)
    sesion.flush()
    return fila


def notificaciones_de(
    sesion: Session, usuario_id: int, solo_no_leidas: bool = False
) -> list[NotificacionORM]:
    consulta = select(NotificacionORM).where(NotificacionORM.usuario_id == usuario_id)
    if solo_no_leidas:
        consulta = consulta.where(NotificacionORM.leida.is_(False))
    return list(
        sesion.scalars(consulta.order_by(NotificacionORM.creada_en.desc()).limit(50)).all()
    )


def marcar_notificacion_leida(sesion: Session, usuario_id: int, notificacion_id: int) -> bool:
    fila = sesion.get(NotificacionORM, notificacion_id)
    if fila is None or fila.usuario_id != usuario_id:
        return False
    fila.leida = True
    sesion.flush()
    return True


def marcar_notificaciones_leidas(sesion: Session, usuario_id: int) -> int:
    filas = notificaciones_de(sesion, usuario_id, solo_no_leidas=True)
    for fila in filas:
        fila.leida = True
    sesion.flush()
    return len(filas)
