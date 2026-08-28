"""Dependencias FastAPI: sesión de BD, identidad JWT y control de roles."""
from __future__ import annotations

from collections.abc import Callable

from fastapi import Depends, Header, HTTPException, status
from sqlalchemy.orm import Session

from app.core.seguridad import decodificar_token
from app.dominio.rbac import roles_de
from app.infra import repositorios as repo
from app.infra.db import abrir_sesion
from app.infra.modelos import UsuarioORM


def obtener_sesion() -> Session:
    sesion = abrir_sesion()
    try:
        yield sesion
    finally:
        sesion.close()


def usuario_actual(
    authorization: str = Header(default=""),
    sesion: Session = Depends(obtener_sesion),
) -> UsuarioORM:
    if not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"codigo": "TOKEN_AUSENTE", "mensaje": "Se requiere Authorization: Bearer <jwt>"},
        )
    payload = decodificar_token(authorization.removeprefix("Bearer ").strip())
    usuario = repo.usuario_por_id(sesion, int(payload["sub"]))
    if usuario is None or not usuario.activo:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"codigo": "USUARIO_INACTIVO", "mensaje": "Usuario inexistente o inactivo"},
        )
    return usuario


def requerir_roles(*roles: str) -> Callable[[UsuarioORM], UsuarioORM]:
    def _verificar(usuario: UsuarioORM = Depends(usuario_actual)) -> UsuarioORM:
        if usuario.rol not in roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={
                    "codigo": "PERMISO_DENEGADO",
                    "mensaje": f"Rol {usuario.rol} sin permiso; requiere: {', '.join(roles)}",
                },
            )
        return usuario

    return _verificar


def requerir_permiso(permiso: str) -> Callable[[UsuarioORM], UsuarioORM]:
    return requerir_roles(*roles_de(permiso))
