"""Auditoría inmutable: escritura-only dentro de la transacción del caso de uso."""
from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy.orm import Session

from app.infra.modelos import AuditLogORM


def registrar(
    sesion: Session,
    usuario_id: int | None,
    accion: str,
    ip_origen: str | None = None,
    valores_previos: dict | None = None,
    valores_nuevos: dict | None = None,
) -> None:
    sesion.add(
        AuditLogORM(
            usuario_id=usuario_id,
            accion=accion,
            timestamp_utc=datetime.now(timezone.utc).replace(tzinfo=None),
            ip_origen=ip_origen,
            valores_previos=valores_previos,
            valores_nuevos=valores_nuevos,
        )
    )
