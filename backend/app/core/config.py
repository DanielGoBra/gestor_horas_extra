"""Configuración central (12-factor: entorno > defaults)."""
from __future__ import annotations

import os
from dataclasses import dataclass, field


def _db_url() -> str:
    url = os.environ.get("GHE_DATABASE_URL", "")
    if url:
        return url
    base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    return f"sqlite:///{os.path.join(base, 'gestor_horas_extra.db')}"


@dataclass(frozen=True)
class Config:
    database_url: str = field(default_factory=_db_url)
    jwt_secret: str = field(
        default_factory=lambda: os.environ.get("GHE_JWT_SECRET", "dev-secret-no-usar-en-produccion")
    )
    jwt_algoritmo: str = "HS256"
    jwt_horas_vigencia: int = field(
        default_factory=lambda: int(os.environ.get("GHE_JWT_HORAS", "8"))
    )
    sqlite_en_memoria: bool = False


CONFIG = Config()

# Modo de enforcement de topes legales: ALERTA (canónico según BDD) permite
# registrar excesos dejando constancia; BLOQUEO rechaza con 409.
BLOQUEAR_TOPES: bool = os.environ.get("GHE_MODO_TOPES", "").upper() == "BLOQUEO"
