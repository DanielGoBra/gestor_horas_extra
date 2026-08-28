"""Contratos de entrada/salida de la API (Pydantic v2)."""
from __future__ import annotations

from datetime import date, datetime
from typing import Literal, Optional

from pydantic import BaseModel, Field


class CredencialesIn(BaseModel):
    codigo: str = Field(min_length=3, max_length=80, examples=["LUISA"])
    password: str = Field(min_length=4, max_length=128)


class UsuarioOut(BaseModel):
    id: int
    codigo: str
    nombre: str
    correo: Optional[str] = None
    area: str
    rol: str


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    usuario: UsuarioOut


class HorarioIn(BaseModel):
    fecha: date
    hora_inicio: str = Field(pattern=r"^([01]\d|2[0-3]):[0-5]\d$", examples=["18:00"])
    hora_fin: str = Field(pattern=r"^([01]\d|2[0-3]):[0-5]\d$", examples=["23:00"])


class SolicitudIn(HorarioIn):
    justificacion: str = Field(min_length=5, max_length=500, description="Actividad realizada")
    observacion_adicional: Optional[str] = Field(default=None, max_length=500)
    solicitante_id: int = Field(ge=1)


class SolicitudEditIn(BaseModel):
    fecha: Optional[date] = None
    hora_inicio: Optional[str] = Field(default=None, pattern=r"^([01]\d|2[0-3]):[0-5]\d$")
    hora_fin: Optional[str] = Field(default=None, pattern=r"^([01]\d|2[0-3]):[0-5]\d$")
    justificacion: Optional[str] = Field(default=None, min_length=5, max_length=500)
    observacion_adicional: Optional[str] = Field(default=None, max_length=500)


class TramoOut(BaseModel):
    inicio_dt: datetime
    fin_dt: datetime
    tipo_hora: str
    minutos: int


class NovedadOut(BaseModel):
    id: int
    colaborador_id: int
    colaborador_codigo: Optional[str] = None
    colaborador_nombre: Optional[str] = None
    area: Optional[str] = None
    solicitante_id: Optional[int] = None
    solicitante_nombre: Optional[str] = None
    fecha_trabajo: date
    justificacion: str
    observacion_adicional: Optional[str] = None
    estado: str
    observacion_rh: Optional[str] = None
    fecha_pago: Optional[date] = None
    total_minutos: int
    tramos: list[TramoOut]


class NotificacionOut(BaseModel):
    id: int
    solicitud_id: Optional[int] = None
    titulo: str
    mensaje: str
    leida: bool
    creada_en: datetime


class SolicitanteOut(BaseModel):
    id: int
    nombre: str
    cargo: str


class SolicitanteIn(BaseModel):
    nombre: str = Field(min_length=3, max_length=120)
    cargo: str = Field(default="", max_length=80)


class ReglasLaboralesOut(BaseModel):
    inicio_diurna: str
    inicio_nocturna: str
    tope_horas_diarias: int
    tope_horas_semanales: int


class ReglasLaboralesIn(BaseModel):
    inicio_diurna: str = Field(pattern=r"^([01]\d|2[0-3]):[0-5]\d$")
    inicio_nocturna: str = Field(pattern=r"^([01]\d|2[0-3]):[0-5]\d$")


class PrevisualizacionOut(BaseModel):
    tramos: list[TramoOut]
    total_minutos: int
    advertencias: list[str]


class RechazoIn(BaseModel):
    observacion: str = Field(default="", max_length=500)


class AprobacionIn(BaseModel):
    observacion: Optional[str] = Field(default=None, max_length=500)


class AprobacionMasivaIn(BaseModel):
    ids: list[int] = Field(min_length=1, max_length=500)


class PeriodoIn(BaseModel):
    etiqueta: str = Field(min_length=4, max_length=64, examples=["2026-Q2-AGOSTO"])
    fecha_inicio: date
    fecha_fin: date


class PeriodoOut(BaseModel):
    id: int
    etiqueta: str
    fecha_inicio: date
    fecha_fin: date
    estado: str
    cerrado_en: Optional[datetime] = None
