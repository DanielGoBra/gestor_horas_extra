"""Excepciones de dominio. Cada una expone un código estable consumido por la API y el cliente."""
from __future__ import annotations


class DominioError(Exception):
    codigo = "ERROR_DOMINIO"

    def __init__(self, mensaje: str = "", codigo: str | None = None):
        super().__init__(mensaje or self.codigo)
        self.mensaje = mensaje or self.codigo
        if codigo:
            self.codigo = codigo


class IntervaloInvalido(DominioError):
    codigo = "INTERVALO_INVALIDO"


class TramosSolapados(DominioError):
    codigo = "TRAMOS_SOLAPADOS"


class TopeDiarioExcedido(DominioError):
    codigo = "TOPE_DIARIO_EXCEDIDO"


class TopeSemanalExcedido(DominioError):
    codigo = "TOPE_SEMANAL_EXCEDIDO"


class EstadoInvalido(DominioError):
    codigo = "ESTADO_INVALIDO"


class PeriodoContableCerrado(DominioError):
    codigo = "PERIODO_CONTABLE_CERRADO"


class ObservacionRequerida(DominioError):
    codigo = "OBSERVACION_REQUERIDA"


class PermisoDenegado(DominioError):
    codigo = "PERMISO_DENEGADO"


class NoEncontrado(DominioError):
    codigo = "NO_ENCONTRADO"


class CredencialesInvalidas(DominioError):
    codigo = "CREDENCIALES_INVALIDAS"
