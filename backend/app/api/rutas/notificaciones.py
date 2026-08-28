"""Notificaciones de cambio de estado para la operativa."""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.dependencias import obtener_sesion, usuario_actual
from app.api.esquemas import NotificacionOut
from app.infra import repositorios as repo
from app.infra.modelos import UsuarioORM

router = APIRouter(prefix="/api/notificaciones", tags=["Notificaciones"])


def _a_out(fila) -> NotificacionOut:
    return NotificacionOut(
        id=fila.id,
        solicitud_id=fila.solicitud_id,
        titulo=fila.titulo,
        mensaje=fila.mensaje,
        leida=fila.leida,
        creada_en=fila.creada_en,
    )


@router.get("", response_model=list[NotificacionOut])
def listar(
    solo_no_leidas: bool = False,
    sesion: Session = Depends(obtener_sesion),
    usuario: UsuarioORM = Depends(usuario_actual),
):
    return [_a_out(f) for f in repo.notificaciones_de(sesion, usuario.id, solo_no_leidas)]


@router.patch("/{notificacion_id}/leer", response_model=NotificacionOut)
def leer(
    notificacion_id: int,
    sesion: Session = Depends(obtener_sesion),
    usuario: UsuarioORM = Depends(usuario_actual),
):
    if not repo.marcar_notificacion_leida(sesion, usuario.id, notificacion_id):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail={"codigo": "NO_ENCONTRADO", "mensaje": "Notificación no encontrada"})
    sesion.commit()
    filas = repo.notificaciones_de(sesion, usuario.id)
    destino = next((f for f in filas if f.id == notificacion_id), None)
    if destino is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail={"codigo": "NO_ENCONTRADO"})
    return _a_out(destino)


@router.post("/leer-todas")
def leer_todas(
    sesion: Session = Depends(obtener_sesion),
    usuario: UsuarioORM = Depends(usuario_actual),
):
    cantidad = repo.marcar_notificaciones_leidas(sesion, usuario.id)
    sesion.commit()
    return {"marcadas": cantidad}
