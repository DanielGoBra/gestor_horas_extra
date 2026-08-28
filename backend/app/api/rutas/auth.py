"""Contexto IAM: autenticación por credenciales y emisión de JWT."""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session

from app.api.dependencias import obtener_sesion
from app.api.esquemas import CredencialesIn, TokenOut, UsuarioOut
from app.core.seguridad import crear_token, verificar_password
from app.infra import auditoria
from app.infra import repositorios as repo

router = APIRouter(prefix="/api/auth", tags=["IAM"])


@router.post("/login", response_model=TokenOut)
def login(credenciales: CredencialesIn, request: Request, sesion: Session = Depends(obtener_sesion)):
    usuario = repo.usuario_por_login(sesion, credenciales.codigo)
    if usuario is None or not verificar_password(credenciales.password, usuario.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"codigo": "CREDENCIALES_INVALIDAS", "mensaje": "Código o contraseña incorrectos"},
        )
    if not usuario.activo:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"codigo": "USUARIO_INACTIVO", "mensaje": "Usuario desactivado"},
        )
    ip = request.client.host if request.client else None
    auditoria.registrar(sesion, usuario.id, "LOGIN", ip_origen=ip)
    sesion.commit()
    return TokenOut(
        access_token=crear_token(usuario.id, usuario.codigo, usuario.rol),
        usuario=UsuarioOut(
            id=usuario.id, codigo=usuario.codigo, nombre=usuario.nombre, correo=usuario.correo, area=usuario.area, rol=usuario.rol
        ),
    )
