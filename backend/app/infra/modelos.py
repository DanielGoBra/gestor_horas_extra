"""Modelos ORM del esquema relacional (docs/04_esquema_datos.md)."""
from __future__ import annotations

from datetime import date, datetime

from sqlalchemy import (
    JSON,
    Boolean,
    Date,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.dominio.entidades import EstadoNovedad
from app.infra.db import Base


class UsuarioORM(Base):
    __tablename__ = "usuarios"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    codigo: Mapped[str] = mapped_column(String(32), unique=True, index=True)
    nombre: Mapped[str] = mapped_column(String(120))
    correo: Mapped[str | None] = mapped_column(String(120), unique=True, nullable=True, index=True)
    area: Mapped[str] = mapped_column(String(80), index=True)
    rol: Mapped[str] = mapped_column(String(32), index=True)
    password_hash: Mapped[str] = mapped_column(String(256))
    activo: Mapped[bool] = mapped_column(Boolean, default=True)


class FestivoORM(Base):
    __tablename__ = "festivos"

    fecha: Mapped[date] = mapped_column(Date, primary_key=True)


class SolicitanteORM(Base):
    __tablename__ = "solicitantes"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    nombre: Mapped[str] = mapped_column(String(120))
    cargo: Mapped[str] = mapped_column(String(80), default="")
    activo: Mapped[bool] = mapped_column(Boolean, default=True)


class ParametroNominaORM(Base):
    __tablename__ = "parametros_nomina"

    clave: Mapped[str] = mapped_column(String(48), primary_key=True)
    valor: Mapped[str] = mapped_column(String(32))


class SolicitudHorasExtraORM(Base):
    __tablename__ = "solicitudes_horas_extra"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    colaborador_id: Mapped[int] = mapped_column(ForeignKey("usuarios.id"), index=True)
    solicitante_id: Mapped[int | None] = mapped_column(
        ForeignKey("solicitantes.id"), nullable=True, index=True
    )
    fecha_trabajo: Mapped[date] = mapped_column(Date, index=True)
    inicio_dt: Mapped[datetime] = mapped_column(DateTime, index=True)
    fin_dt: Mapped[datetime] = mapped_column(DateTime, index=True)
    justificacion: Mapped[str] = mapped_column(Text)
    observacion_adicional: Mapped[str | None] = mapped_column(Text, nullable=True)
    estado: Mapped[str] = mapped_column(
        String(24), default=EstadoNovedad.PENDIENTE_APROBACION.value, index=True
    )
    observacion_rh: Mapped[str | None] = mapped_column(Text, nullable=True)
    fecha_pago: Mapped[date | None] = mapped_column(Date, nullable=True)
    aprobada_por: Mapped[int | None] = mapped_column(ForeignKey("usuarios.id"), nullable=True)
    creada_en: Mapped[datetime] = mapped_column(DateTime)
    actualizada_en: Mapped[datetime] = mapped_column(DateTime)

    tramos: Mapped[list["TramoDetalleORM"]] = relationship(
        back_populates="solicitud", cascade="all, delete-orphan", lazy="joined"
    )
    solicitante: Mapped[SolicitanteORM | None] = relationship(lazy="joined")


class TramoDetalleORM(Base):
    __tablename__ = "tramos_detalle"
    __table_args__ = (UniqueConstraint("solicitud_id", "inicio_dt", name="uq_tramo_inicio"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    solicitud_id: Mapped[int] = mapped_column(
        ForeignKey("solicitudes_horas_extra.id"), index=True
    )
    inicio_dt: Mapped[datetime] = mapped_column(DateTime)
    fin_dt: Mapped[datetime] = mapped_column(DateTime)
    tipo_hora: Mapped[str] = mapped_column(String(24))
    minutos: Mapped[int] = mapped_column(Integer)

    solicitud: Mapped[SolicitudHorasExtraORM] = relationship(back_populates="tramos")


class CorteNominaORM(Base):
    __tablename__ = "cortes_nomina"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    etiqueta: Mapped[str] = mapped_column(String(64), unique=True)
    fecha_inicio: Mapped[date] = mapped_column(Date)
    fecha_fin: Mapped[date] = mapped_column(Date)
    estado: Mapped[str] = mapped_column(String(12), default="ABIERTO", index=True)
    cerrado_en: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    cerrado_por: Mapped[int | None] = mapped_column(ForeignKey("usuarios.id"), nullable=True)


class NotificacionORM(Base):
    __tablename__ = "notificaciones"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    usuario_id: Mapped[int] = mapped_column(ForeignKey("usuarios.id"), index=True)
    solicitud_id: Mapped[int | None] = mapped_column(
        ForeignKey("solicitudes_horas_extra.id"), nullable=True, index=True
    )
    titulo: Mapped[str] = mapped_column(String(160))
    mensaje: Mapped[str] = mapped_column(Text)
    leida: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    creada_en: Mapped[datetime] = mapped_column(DateTime)


class AuditLogORM(Base):
    __tablename__ = "audit_log"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    usuario_id: Mapped[int | None] = mapped_column(ForeignKey("usuarios.id"), nullable=True)
    accion: Mapped[str] = mapped_column(String(48), index=True)
    timestamp_utc: Mapped[datetime] = mapped_column(DateTime)
    ip_origen: Mapped[str | None] = mapped_column(String(64), nullable=True)
    valores_previos: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    valores_nuevos: Mapped[dict | None] = mapped_column(JSON, nullable=True)
