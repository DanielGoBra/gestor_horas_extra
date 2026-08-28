"""Semilla idempotente: equipo INKLUSIVA, festivos, quincena y registros tipo Forms."""
from __future__ import annotations

import calendar
from datetime import date, datetime, time, timedelta

from sqlalchemy import func, inspect, select, text

from app.core.seguridad import hash_password
from app.dominio.entidades import EstadoNovedad, RegistroNovedad
from app.dominio.motor_reglas import calcular_tramos
from app.infra import db as infra_db
from app.infra.modelos import (
    CorteNominaORM,
    FestivoORM,
    ParametroNominaORM,
    SolicitanteORM,
    SolicitudHorasExtraORM,
    TramoDetalleORM,
    UsuarioORM,
)

_SOLICITANTES = [
    ("Hernán Darío Giraldo Carmona", "Jefe comercial"),
    ("Natalia Ramírez Echavarría", "Jefe comercial"),
]
_SOLICITANTES_RETIRADOS = ("Miguel Andrés Agudelo Agudelo",)

_PARAMETROS = [
    ("inicio_diurna", "06:00"),
    ("inicio_nocturna", "21:00"),
]

_FESTIVOS_2026 = [
    date(2026, 1, 1), date(2026, 5, 1), date(2026, 5, 18),
    date(2026, 6, 15), date(2026, 6, 29), date(2026, 7, 20),
    date(2026, 8, 7), date(2026, 8, 17), date(2026, 10, 12),
    date(2026, 11, 2), date(2026, 11, 16), date(2026, 12, 8), date(2026, 12, 25),
]

# codigo, nombre, correo, area, rol, clave
_USUARIOS = [
    ("ADMIN-1", "Admin INKLUSIVA", "usuario@example.com", "Sistemas", "ADMIN", "admin123"),
    ("ADRIANA", "Colaborador 7", "usuario@example.com", "RecursosHumanos", "RH", "inklusiva"),
    ("JULIANA", "Colaborador 5", "usuario@example.com", "RecursosHumanos", "RH", "inklusiva"),
    ("JEFEOP", "Jefe de Operaciones", "usuario@example.com", "Operaciones", "JEFE_OPERACIONES", "inklusiva"),
    ("LUISA", "Colaborador 2", "usuario@example.com", "Operaciones", "OPERATIVO", "inklusiva"),
    ("JOANNA", "Colaborador 8", "usuario@example.com", "Operaciones", "OPERATIVO", "inklusiva"),
    ("MARILUZ", "Colaborador 3", "usuario@example.com", "Operaciones", "OPERATIVO", "inklusiva"),
    ("YORLADIS", "Colaborador 1", "usuario@example.com", "Operaciones", "OPERATIVO", "inklusiva"),
]


def quincena_actual(hoy: date | None = None) -> tuple[date, date]:
    hoy = hoy or date.today()
    ultimo_dia = calendar.monthrange(hoy.year, hoy.month)[1]
    if hoy.day <= 15:
        return date(hoy.year, hoy.month, 1), date(hoy.year, hoy.month, 15)
    return date(hoy.year, hoy.month, 16), date(hoy.year, hoy.month, ultimo_dia)


def _crear_novedad(
    sesion,
    colaborador_id: int,
    fecha: date,
    hora_inicio: time,
    hora_fin: time,
    justificacion: str,
    estado_final: EstadoNovedad,
    rh_id: int,
    solicitante_id: int | None = None,
    solicitante_nombre: str | None = None,
    observacion: str | None = None,
    observacion_adicional: str | None = None,
) -> None:
    festivos = {f for f in _FESTIVOS_2026}
    tramos = calcular_tramos(fecha, hora_inicio, hora_fin, frozenset(festivos))
    ahora = datetime.utcnow()
    novedad = RegistroNovedad.crear(
        colaborador_id,
        fecha,
        justificacion,
        tramos,
        ahora,
        solicitante_id=solicitante_id,
        solicitante_nombre=solicitante_nombre,
        observacion_adicional=observacion_adicional,
    )
    if estado_final is EstadoNovedad.APROBADA:
        novedad.aprobar(rh_id, ahora)
    elif estado_final is EstadoNovedad.RECHAZADA:
        novedad.rechazar(rh_id, ahora, observacion or "Ajuste requerido")
    fila = SolicitudHorasExtraORM(
        colaborador_id=novedad.colaborador_id,
        solicitante_id=solicitante_id,
        fecha_trabajo=novedad.fecha_trabajo,
        inicio_dt=min(t.inicio_dt for t in novedad.tramos),
        fin_dt=max(t.fin_dt for t in novedad.tramos),
        justificacion=novedad.justificacion,
        observacion_adicional=novedad.observacion_adicional,
        estado=novedad.estado.value,
        observacion_rh=novedad.observacion_rh,
        aprobada_por=novedad.aprobada_por,
        creada_en=ahora,
        actualizada_en=ahora,
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


def _migrar_sqlite() -> None:
    inspector = inspect(infra_db.engine)
    tablas = inspector.get_table_names()
    if "usuarios" in tablas:
        columnas_u = {c["name"] for c in inspector.get_columns("usuarios")}
        if "correo" not in columnas_u:
            with infra_db.engine.begin() as conn:
                conn.execute(text("ALTER TABLE usuarios ADD COLUMN correo VARCHAR(120)"))
    if "solicitudes_horas_extra" not in tablas:
        return
    columnas = {c["name"] for c in inspector.get_columns("solicitudes_horas_extra")}
    with infra_db.engine.begin() as conn:
        if "solicitante_id" not in columnas:
            conn.execute(text("ALTER TABLE solicitudes_horas_extra ADD COLUMN solicitante_id INTEGER"))
        if "observacion_adicional" not in columnas:
            conn.execute(text("ALTER TABLE solicitudes_horas_extra ADD COLUMN observacion_adicional TEXT"))
        if "fecha_pago" not in columnas:
            conn.execute(text("ALTER TABLE solicitudes_horas_extra ADD COLUMN fecha_pago DATE"))


def _sembrar_catalogos(sesion) -> None:
    if sesion.scalar(select(func.count()).select_from(ParametroNominaORM)) == 0:
        sesion.add_all([ParametroNominaORM(clave=k, valor=v) for k, v in _PARAMETROS])
    existentes = {s.nombre: s for s in sesion.scalars(select(SolicitanteORM)).all()}
    for nombre, cargo in _SOLICITANTES:
        fila = existentes.get(nombre)
        if fila is None:
            sesion.add(SolicitanteORM(nombre=nombre, cargo=cargo, activo=True))
        else:
            fila.cargo = cargo
            fila.activo = True
    for nombre in _SOLICITANTES_RETIRADOS:
        fila = existentes.get(nombre)
        if fila is not None:
            fila.activo = False
    sesion.flush()


def _asegurar_usuarios(sesion) -> None:
    existentes = {u.codigo: u for u in sesion.scalars(select(UsuarioORM)).all()}
    for codigo, nombre, correo, area, rol, clave in _USUARIOS:
        fila = existentes.get(codigo)
        if fila is None:
            sesion.add(
                UsuarioORM(
                    codigo=codigo,
                    nombre=nombre,
                    correo=correo,
                    area=area,
                    rol=rol,
                    password_hash=hash_password(clave),
                    activo=True,
                )
            )
        else:
            fila.nombre = nombre
            fila.correo = correo
            fila.area = area
            fila.rol = rol
    sesion.flush()


def inicializar(solo_si_vacio: bool = True) -> None:
    infra_db.Base.metadata.create_all(bind=infra_db.engine)
    _migrar_sqlite()
    sesion = infra_db.abrir_sesion()
    try:
        hay_usuarios = sesion.scalar(select(func.count()).select_from(UsuarioORM)) > 0
        _sembrar_catalogos(sesion)
        if solo_si_vacio and hay_usuarios:
            _asegurar_usuarios(sesion)
            sesion.commit()
            return

        _asegurar_usuarios(sesion)
        if sesion.scalar(select(func.count()).select_from(FestivoORM)) == 0:
            sesion.add_all([FestivoORM(fecha=f) for f in _FESTIVOS_2026])
        sesion.flush()

        ids = {u.codigo: u.id for u in sesion.scalars(select(UsuarioORM)).all()}
        solicitantes = {s.nombre: s for s in sesion.scalars(select(SolicitanteORM)).all()}
        hernan = solicitantes["Hernán Darío Giraldo Carmona"]
        natalia = solicitantes["Natalia Ramírez Echavarría"]
        jefe_id = ids["JEFEOP"]
        inicio_q, fin_q = quincena_actual()
        ayer = max(date.today() - timedelta(days=1), inicio_q)

        _crear_novedad(
            sesion, ids["LUISA"], ayer, time(18, 0), time(19, 0),
            "Desembolso hasta las 5. Compañera en vacaciones, solo estamos desembolsando dos personas.",
            EstadoNovedad.PENDIENTE_APROBACION, jefe_id,
            solicitante_id=hernan.id, solicitante_nombre=hernan.nombre,
        )
        _crear_novedad(
            sesion, ids["YORLADIS"], ayer, time(16, 0), time(20, 30),
            "Aplicación de pagos manuales por cierre",
            EstadoNovedad.PENDIENTE_APROBACION, jefe_id,
            solicitante_id=natalia.id, solicitante_nombre=natalia.nombre,
        )
        _crear_novedad(
            sesion, ids["MARILUZ"], inicio_q, time(18, 0), time(20, 30),
            "Cierre de mes, se realiza reasignación de carteras.",
            EstadoNovedad.APROBADA, jefe_id,
            solicitante_id=hernan.id, solicitante_nombre=hernan.nombre,
        )
        _crear_novedad(
            sesion, ids["JOANNA"], min(fin_q, date.today()), time(18, 0), time(21, 0),
            "Acompañamiento de pagos",
            EstadoNovedad.PENDIENTE_APROBACION, jefe_id,
            solicitante_id=hernan.id, solicitante_nombre=hernan.nombre,
            observacion_adicional="Jornada extendida por vacaciones del equipo.",
        )

        sesion.add(
            CorteNominaORM(
                etiqueta=f"{inicio_q.isoformat()}_{fin_q.isoformat()}",
                fecha_inicio=inicio_q,
                fecha_fin=fin_q,
                estado="ABIERTO",
            )
        )
        sesion.commit()
    finally:
        sesion.close()
