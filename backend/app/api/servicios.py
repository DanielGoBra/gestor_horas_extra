"""Casos de uso de aplicación: orquestan dominio, repositorios y auditoría."""
from __future__ import annotations

import threading
from datetime import date, datetime, time, timedelta

from sqlalchemy.orm import Session

from app.core import config as configuracion
from app.dominio.entidades import EstadoNovedad, RegistroNovedad
from app.dominio.excepciones import (
    DominioError,
    EstadoInvalido,
    IntervaloInvalido,
    NoEncontrado,
    PermisoDenegado,
    PeriodoContableCerrado,
    TopeDiarioExcedido,
    TopeSemanalExcedido,
    TramosSolapados,
)
from app.dominio.motor_reglas import (
    ParametrosReglas,
    calcular_tramos,
    minutos_por_fecha,
    semana_iso,
    total_minutos,
)
from app.dominio.rbac import Permiso, Rol, tiene_permiso
from app.infra import auditoria, repositorios as repo
from app.infra.modelos import UsuarioORM

_locks_por_colaborador: dict[int, threading.Lock]
_locks_por_colaborador = {}
_guarda_locks = threading.Lock()


def _lock_de(colaborador_id: int) -> threading.Lock:
    with _guarda_locks:
        if colaborador_id not in _locks_por_colaborador:
            _locks_por_colaborador[colaborador_id] = threading.Lock()
        return _locks_por_colaborador[colaborador_id]


def _parse_hora(valor: str) -> time:
    hh, mm = valor.split(":")
    return time(int(hh), int(mm))


def _asegurar_periodo_abierto(sesion: Session, fecha: date) -> None:
    periodo = repo.periodo_que_cubre(sesion, fecha)
    if periodo is not None and periodo.estado == "CERRADO":
        raise PeriodoContableCerrado(
            f"La fecha {fecha.isoformat()} pertenece al periodo cerrado '{periodo.etiqueta}'"
        )


def _validar_topes(
    sesion: Session,
    colaborador_id: int,
    nuevos_por_fecha: dict[date, int],
    params: ParametrosReglas,
) -> list[str]:
    fechas = sorted(nuevos_por_fecha)
    desde_dt = datetime.combine(fechas[0] - timedelta(days=7), time(0, 0))
    hasta_dt = datetime.combine(fechas[-1] + timedelta(days=2), time(0, 0))
    existentes = repo.minutos_comprometidos_por_fecha(
        sesion, colaborador_id, desde_dt, hasta_dt
    )
    combinado: dict[date, int] = dict(existentes)
    advertencias: list[str] = []
    for f, mins in nuevos_por_fecha.items():
        combinado[f] = combinado.get(f, 0) + mins

    for f in sorted(combinado):
        if combinado[f] > params.tope_minutos_diarios:
            detalle = (
                f"El día {f.isoformat()} acumula {combinado[f]} min "
                f"(tope {params.tope_minutos_diarios} min)"
            )
            if configuracion.BLOQUEAR_TOPES:
                raise TopeDiarioExcedido(detalle)
            advertencias.append(f"TOPE_DIARIO: {detalle}")

    por_semana: dict[tuple[int, int], int] = {}
    for f, mins in combinado.items():
        clave = semana_iso(f)
        por_semana[clave] = por_semana.get(clave, 0) + mins
    for clave, mins in sorted(por_semana.items()):
        if mins > params.tope_minutos_semanales:
            detalle = (
                f"La semana ISO {clave} acumula {mins} min "
                f"(tope {params.tope_minutos_semanales} min)"
            )
            if configuracion.BLOQUEAR_TOPES:
                raise TopeSemanalExcedido(detalle)
            advertencias.append(f"TOPE_SEMANAL: {detalle}")
    return advertencias


def previsualizar(
    sesion: Session,
    colaborador_id: int,
    fecha: date,
    hora_inicio: str,
    hora_fin: str,
) -> tuple[list, int, list[str]]:
    params = repo.parametros_vigentes(sesion)
    festivos = repo.festivos_como_conjunto(sesion, fecha - timedelta(days=1), fecha + timedelta(days=2))
    tramos = calcular_tramos(fecha, _parse_hora(hora_inicio), _parse_hora(hora_fin), festivos, params)
    advertencias = _validar_topes(sesion, colaborador_id, minutos_por_fecha(tramos), params)
    return tramos, total_minutos(tramos), advertencias


def solicitar_novedad(
    sesion: Session,
    usuario: UsuarioORM,
    fecha: date,
    hora_inicio: str,
    hora_fin: str,
    justificacion: str,
    ip_origen: str | None,
    ahora: datetime | None = None,
    solicitante_id: int | None = None,
    observacion_adicional: str | None = None,
) -> RegistroNovedad:
    ahora = ahora or datetime.utcnow()
    _asegurar_periodo_abierto(sesion, fecha)
    params = repo.parametros_vigentes(sesion)
    festivos = repo.festivos_como_conjunto(sesion, fecha - timedelta(days=1), fecha + timedelta(days=2))
    try:
        tramos = calcular_tramos(fecha, _parse_hora(hora_inicio), _parse_hora(hora_fin), festivos, params)
    except IntervaloInvalido:
        raise
    ini_dt = min(t.inicio_dt for t in tramos)
    fin_dt = max(t.fin_dt for t in tramos)

    solicitante = None
    if solicitante_id is not None:
        solicitante = repo.solicitante_por_id(sesion, solicitante_id)
        if solicitante is None or not solicitante.activo:
            raise NoEncontrado("El solicitante no existe o está inactivo")

    with _lock_de(usuario.id):
        if repo.existe_solapamiento(sesion, usuario.id, ini_dt, fin_dt):
            raise TramosSolapados(
                f"Ya existe una novedad viva entre {ini_dt:%H:%M} y {fin_dt:%H:%M}"
            )
        nuevos_por_fecha = minutos_por_fecha(tramos)
        _validar_topes(sesion, usuario.id, nuevos_por_fecha, params)

        novedad = RegistroNovedad.crear(
            usuario.id,
            fecha,
            justificacion,
            tramos,
            ahora,
            solicitante_id=solicitante.id if solicitante else None,
            solicitante_nombre=solicitante.nombre if solicitante else None,
            observacion_adicional=observacion_adicional,
        )
        repo.guardar_novedad(sesion, novedad)
        auditoria.registrar(
            sesion,
            usuario.id,
            "CREAR_NOVEDAD",
            ip_origen,
            valores_nuevos={
                "solicitud_id": novedad.id,
                "fecha": fecha.isoformat(),
                "inicio": ini_dt.isoformat(),
                "fin": fin_dt.isoformat(),
                "tramos": [
                    {"tipo": t.tipo_hora.value, "minutos": t.minutos} for t in novedad.tramos
                ],
            },
        )
        sesion.commit()
    return novedad


def editar_novedad(
    sesion: Session,
    usuario: UsuarioORM,
    novedad_id: int,
    cambios: dict,
    ip_origen: str | None,
    ahora: datetime | None = None,
) -> RegistroNovedad:
    ahora = ahora or datetime.utcnow()
    novedad = repo.novedad_por_id(sesion, novedad_id)
    if novedad is None:
        raise NoEncontrado("La novedad no existe")
    if novedad.colaborador_id != usuario.id and usuario.rol == "OPERATIVO":
        raise PermisoDenegado("Solo puedes editar tus propias novedades")
    _asegurar_periodo_abierto(sesion, novedad.fecha_trabajo)
    if novedad.estado in (EstadoNovedad.APROBADA, EstadoNovedad.CERRADA_EN_NOMINA):
        raise EstadoInvalido(f"La novedad está en estado {novedad.estado.value}")


    previos = {
        "fecha": novedad.fecha_trabajo.isoformat(),
        "justificacion": novedad.justificacion,
        "estado": novedad.estado.value,
    }
    fecha = cambios.get("fecha") or novedad.fecha_trabajo
    tramos_actuales = sorted(novedad.tramos, key=lambda t: t.inicio_dt)
    hora_inicio = cambios.get("hora_inicio") or tramos_actuales[0].inicio_dt.strftime("%H:%M")
    hora_fin = cambios.get("hora_fin") or tramos_actuales[-1].fin_dt.strftime("%H:%M")
    justificacion = cambios.get("justificacion") or novedad.justificacion
    if "observacion_adicional" in cambios:
        extra = (cambios.get("observacion_adicional") or "").strip() or None
        novedad.observacion_adicional = extra

    _asegurar_periodo_abierto(sesion, fecha)
    params = repo.parametros_vigentes(sesion)
    festivos = repo.festivos_como_conjunto(sesion, fecha - timedelta(days=1), fecha + timedelta(days=2))
    tramos = calcular_tramos(fecha, _parse_hora(hora_inicio), _parse_hora(hora_fin), festivos, params)
    ini_dt = min(t.inicio_dt for t in tramos)
    fin_dt = max(t.fin_dt for t in tramos)

    with _lock_de(usuario.id):
        if repo.existe_solapamiento(sesion, usuario.id, ini_dt, fin_dt, excluir_solicitud_id=novedad.id):
            raise TramosSolapados("Los nuevos horarios solapan otra novedad viva")
        _validar_topes(sesion, usuario.id, minutos_por_fecha(tramos), params)
        novedad.fecha_trabajo = fecha
        novedad.justificacion = justificacion
        novedad.reemplazar_tramos(tramos, ahora)
        repo.guardar_novedad(sesion, novedad)
        auditoria.registrar(
            sesion,
            usuario.id,
            "EDITAR_NOVEDAD",
            ip_origen,
            valores_previos=previos,
            valores_nuevos={"solicitud_id": novedad.id, "fecha": fecha.isoformat()},
        )
        sesion.commit()
    return novedad


def cancelar_novedad(
    sesion: Session, usuario: UsuarioORM, novedad_id: int, ip_origen: str | None
) -> None:
    novedad = repo.novedad_por_id(sesion, novedad_id)
    if novedad is None:
        raise NoEncontrado("La novedad no existe")
    if novedad.colaborador_id != usuario.id and usuario.rol != Rol.ADMIN:
        raise PermisoDenegado("Solo puedes cancelar tus propias novedades")
    _asegurar_periodo_abierto(sesion, novedad.fecha_trabajo)
    if not novedad.editable:
        raise EstadoInvalido(f"No se puede cancelar en estado {novedad.estado.value}")
    fila = repo.fila_novedad(sesion, novedad_id)
    sesion.delete(fila)
    auditoria.registrar(
        sesion,
        usuario.id,
        "CANCELAR_NOVEDAD",
        ip_origen,
        valores_previos={
            "solicitud_id": novedad_id,
            "fecha": novedad.fecha_trabajo.isoformat(),
            "estado": novedad.estado.value,
        },
    )
    sesion.commit()


def aprobar(
    sesion: Session,
    rh: UsuarioORM,
    novedad_id: int,
    observacion: str | None,
    ip_origen: str | None,
) -> RegistroNovedad:
    return _cambiar_estado(sesion, rh, novedad_id, "APROBAR", observacion, ip_origen)


def rechazar(
    sesion: Session, rh: UsuarioORM, novedad_id: int, observacion: str, ip_origen: str | None
) -> RegistroNovedad:
    return _cambiar_estado(sesion, rh, novedad_id, "RECHAZAR", observacion, ip_origen)


def _cambiar_estado(
    sesion: Session,
    rh: UsuarioORM,
    novedad_id: int,
    accion: str,
    observacion: str | None,
    ip_origen: str | None,
) -> RegistroNovedad:
    if not tiene_permiso(rh.rol, Permiso.APROBAR_HORAS):
        raise PermisoDenegado("Solo el jefe de operaciones puede aprobar o rechazar horas extra")
    ahora = datetime.utcnow()
    with _lock_de(-1):
        novedad = repo.novedad_por_id(sesion, novedad_id)
        if novedad is None:
            raise NoEncontrado("La novedad no existe")
        previos = {"estado": novedad.estado.value}
        if accion == "APROBAR":
            novedad.aprobar(rh.id, ahora, observacion)
            titulo = "Horas extra aprobadas"
            etiqueta = "Aprobado"
        else:
            novedad.rechazar(rh.id, ahora, observacion or "")
            titulo = "Horas extra rechazadas"
            etiqueta = "Rechazado"
        repo.guardar_novedad(sesion, novedad)
        repo.crear_notificacion(
            sesion,
            novedad.colaborador_id,
            titulo,
            (
                f"Tu registro del {novedad.fecha_trabajo.strftime('%d/%m/%Y')} pasó de "
                f"En revisión a {etiqueta}."
                + (f" Observación: {observacion}" if observacion else "")
            ),
            solicitud_id=novedad.id,
        )
        auditoria.registrar(
            sesion,
            rh.id,
            f"{accion}_NOVEDAD",
            ip_origen,
            valores_previos=previos,
            valores_nuevos={"solicitud_id": novedad_id, "estado": novedad.estado.value},
        )
        sesion.commit()
    return novedad


def aprobar_masivo(
    sesion: Session, rh: UsuarioORM, ids: list[int], ip_origen: str | None
) -> list[int]:
    """Transacción atómica: todo o nada (NFR de consistencia ACID)."""
    if not tiene_permiso(rh.rol, Permiso.APROBAR_HORAS):
        raise PermisoDenegado("Solo el jefe de operaciones puede aprobar horas extra")
    ahora = datetime.utcnow()
    aprobadas: list[int] = []
    try:
        for novedad_id in ids:
            novedad = repo.novedad_por_id(sesion, novedad_id)
            if novedad is None:
                raise NoEncontrado(f"Novedad {novedad_id} no existe")
            novedad.aprobar(rh.id, ahora)
            repo.guardar_novedad(sesion, novedad)
            repo.crear_notificacion(
                sesion,
                novedad.colaborador_id,
                "Horas extra aprobadas",
                f"Tu registro del {novedad.fecha_trabajo.strftime('%d/%m/%Y')} pasó de En revisión a Aprobado.",
                solicitud_id=novedad.id,
            )
            aprobadas.append(novedad_id)
        auditoria.registrar(
            sesion,
            rh.id,
            "APROBAR_MASIVO",
            ip_origen,
            valores_nuevos={"ids": aprobadas},
        )
        sesion.commit()
    except Exception:
        sesion.rollback()
        raise
    return aprobadas


def crear_periodo(
    sesion: Session, rh: UsuarioORM, etiqueta: str, fecha_inicio: date, fecha_fin: date
):
    if not tiene_permiso(rh.rol, Permiso.GESTIONAR_PERIODOS):
        raise PermisoDenegado("No puede gestionar periodos de nómina")
    if fecha_fin < fecha_inicio:
        raise DominioError("RANGO_INVALIDO", codigo="RANGO_INVALIDO")
    if repo.periodo_por_etiqueta(sesion, etiqueta) is not None:
        raise DominioError("PERIODO_YA_EXISTE", codigo="PERIODO_YA_EXISTE")
    periodo = repo.crear_periodo(sesion, etiqueta, fecha_inicio, fecha_fin)
    auditoria.registrar(
        sesion,
        rh.id,
        "CREAR_PERIODO",
        valores_nuevos={"etiqueta": etiqueta, "desde": fecha_inicio.isoformat(), "hasta": fecha_fin.isoformat()},
    )
    sesion.commit()
    return periodo


def cerrar_periodo(sesion: Session, rh: UsuarioORM, periodo_id: int):
    if not tiene_permiso(rh.rol, Permiso.GESTIONAR_PERIODOS):
        raise PermisoDenegado("No puede gestionar periodos de nómina")
    ahora = datetime.utcnow()
    with _lock_de(-2):
        periodo = repo.periodo_por_id(sesion, periodo_id)
        if periodo is None:
            raise NoEncontrado("Periodo no existe")
        if periodo.estado == "CERRADO":
            raise DominioError("PERIODO_YA_CERRADO", codigo="PERIODO_YA_CERRADO")
        congeladas = repo.congelar_aprobadas_del_periodo(sesion, periodo, ahora)
        periodo.estado = "CERRADO"
        periodo.cerrado_en = ahora
        periodo.cerrado_por = rh.id
        auditoria.registrar(
            sesion,
            rh.id,
            "CERRAR_PERIODO",
            valores_nuevos={"etiqueta": periodo.etiqueta, "congeladas": len(congeladas)},
        )
        sesion.commit()
    return periodo, congeladas


