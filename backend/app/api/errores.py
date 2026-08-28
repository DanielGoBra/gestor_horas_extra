"""Mapeo de errores de dominio a respuestas HTTP con código estable."""
from __future__ import annotations

from fastapi import HTTPException, status

from app.dominio.excepciones import DominioError

_HTTP_422 = getattr(status, "HTTP_422_UNPROCESSABLE_CONTENT", 422)

_ESTADO = {
    "TRAMOS_SOLAPADOS": status.HTTP_409_CONFLICT,
    "TOPE_DIARIO_EXCEDIDO": status.HTTP_409_CONFLICT,
    "TOPE_SEMANAL_EXCEDIDO": status.HTTP_409_CONFLICT,
    "ESTADO_INVALIDO": status.HTTP_409_CONFLICT,
    "PERIODO_CONTABLE_CERRADO": status.HTTP_409_CONFLICT,
    "PERIODO_YA_CERRADO": status.HTTP_409_CONFLICT,
    "PERIODO_YA_EXISTE": status.HTTP_409_CONFLICT,
    "RANGO_INVALIDO": _HTTP_422,
    "INTERVALO_INVALIDO": _HTTP_422,
    "OBSERVACION_REQUERIDA": _HTTP_422,
    "PERMISO_DENEGADO": status.HTTP_403_FORBIDDEN,
    "NO_ENCONTRADO": status.HTTP_404_NOT_FOUND,
    "CREDENCIALES_INVALIDAS": status.HTTP_401_UNAUTHORIZED,
}


def dominio_a_http(exc: DominioError) -> HTTPException:
    codigo_http = _ESTADO.get(exc.codigo, status.HTTP_400_BAD_REQUEST)
    return HTTPException(
        status_code=codigo_http,
        detail={"codigo": exc.codigo, "mensaje": exc.mensaje},
    )

