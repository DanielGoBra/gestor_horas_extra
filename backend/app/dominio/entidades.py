"""Agregado raíz RegistroNovedad con su entidad hija TramoHorario.

Encapsula las invariantes de ciclo de vida; la persistencia vive en infra.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date, datetime
from enum import Enum

from app.dominio.excepciones import (
    EstadoInvalido,
    ObservacionRequerida,
)
from app.dominio.motor_reglas import TramoCalculado, TipoHora


class EstadoNovedad(str, Enum):
    PENDIENTE_APROBACION = "PENDIENTE_APROBACION"
    APROBADA = "APROBADA"
    RECHAZADA = "RECHAZADA"
    CERRADA_EN_NOMINA = "CERRADA_EN_NOMINA"


@dataclass(frozen=True)
class TramoHorario:
    inicio_dt: datetime
    fin_dt: datetime
    tipo_hora: TipoHora

    def __post_init__(self):
        if isinstance(self.tipo_hora, str):
            object.__setattr__(self, "tipo_hora", TipoHora(self.tipo_hora))

    @property
    def minutos(self) -> int:
        return int((self.fin_dt - self.inicio_dt).total_seconds() // 60)

    @classmethod
    def desde_calculo(cls, tramo: TramoCalculado) -> "TramoHorario":
        return cls(tramo.inicio_dt, tramo.fin_dt, tramo.tipo_hora)


@dataclass
class RegistroNovedad:
    id: int | None
    colaborador_id: int
    fecha_trabajo: date
    justificacion: str
    observacion_adicional: str | None = None
    estado: EstadoNovedad = EstadoNovedad.PENDIENTE_APROBACION
    observacion_rh: str | None = None
    aprobada_por: int | None = None
    solicitante_id: int | None = None
    solicitante_nombre: str | None = None
    creada_en: datetime | None = None
    actualizada_en: datetime | None = None
    fecha_pago: date | None = None
    tramos: list[TramoHorario] = field(default_factory=list)

    @classmethod
    def crear(
        cls,
        colaborador_id: int,
        fecha_trabajo: date,
        justificacion: str,
        tramos_calculados: list[TramoCalculado],
        ahora: datetime,
        solicitante_id: int | None = None,
        solicitante_nombre: str | None = None,
        observacion_adicional: str | None = None,
    ) -> "RegistroNovedad":
        if not justificacion or not justificacion.strip():
            raise ValueError("JUSTIFICACION_REQUERIDA")
        if not tramos_calculados:
            raise ValueError("INTERVALO_INVALIDO")
        extra = (observacion_adicional or "").strip() or None
        novedad = cls(
            id=None,
            colaborador_id=colaborador_id,
            fecha_trabajo=fecha_trabajo,
            justificacion=justificacion.strip(),
            observacion_adicional=extra,
            solicitante_id=solicitante_id,
            solicitante_nombre=solicitante_nombre,
            creada_en=ahora,
            actualizada_en=ahora,
            tramos=[TramoHorario.desde_calculo(t) for t in tramos_calculados],
        )
        return novedad

    @property
    def editable(self) -> bool:
        return self.estado in (EstadoNovedad.PENDIENTE_APROBACION, EstadoNovedad.RECHAZADA)

    def reemplazar_tramos(self, tramos: list[TramoCalculado], ahora: datetime) -> None:
        if not self.editable:
            raise EstadoInvalido(f"La novedad en estado {self.estado.value} no es editable")
        if not tramos:
            raise ValueError("INTERVALO_INVALIDO")
        self.tramos = [TramoHorario.desde_calculo(t) for t in tramos]
        self.estado = EstadoNovedad.PENDIENTE_APROBACION
        self.observacion_rh = None
        self.actualizada_en = ahora

    def aprobar(self, rh_id: int, ahora: datetime, observacion: str | None = None) -> None:
        if self.estado is not EstadoNovedad.PENDIENTE_APROBACION:
            raise EstadoInvalido(f"Solo PENDIENTE_APROBACION puede aprobarse; estado actual {self.estado.value}")
        self.estado = EstadoNovedad.APROBADA
        self.aprobada_por = rh_id
        self.observacion_rh = observacion or None
        self.actualizada_en = ahora

    def rechazar(self, rh_id: int, ahora: datetime, observacion: str) -> None:
        if not observacion or not observacion.strip():
            raise ObservacionRequerida("El rechazo exige observación para el colaborador")
        if self.estado not in (EstadoNovedad.PENDIENTE_APROBACION,):
            raise EstadoInvalido(f"Solo PENDIENTE_APROBACION puede rechazarse; estado actual {self.estado.value}")
        self.estado = EstadoNovedad.RECHAZADA
        self.aprobada_por = rh_id
        self.observacion_rh = observacion.strip()
        self.actualizada_en = ahora

    def cerrar_en_nomina(self, ahora: datetime) -> None:
        if self.estado is not EstadoNovedad.APROBADA:
            raise EstadoInvalido("Solo novedades APROBADA se cierran en nómina")
        self.estado = EstadoNovedad.CERRADA_EN_NOMINA
        self.actualizada_en = ahora
