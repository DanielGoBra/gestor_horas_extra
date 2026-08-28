"""Contexto de Registro y Novedades (rol Operativo)."""
from __future__ import annotations

from fastapi import APIRouter, Depends, Request, status
from sqlalchemy.orm import Session

from app.api.dependencias import obtener_sesion, requerir_permiso
from app.api.errores import dominio_a_http
from app.api.esquemas import (
    HorarioIn,
    NovedadOut,
    PrevisualizacionOut,
    SolicitudEditIn,
    SolicitudIn,
)
from app.api.presentacion import a_novedad_out, a_tramo_out
from app.dominio.excepciones import DominioError
from app.dominio.rbac import Permiso
from app.infra import repositorios as repo
from app.api import servicios
from app.infra.modelos import UsuarioORM

router = APIRouter(prefix="/api/horas-extra", tags=["Registro y Novedades"])


@router.post("/previsualizar", response_model=PrevisualizacionOut)
def previsualizar(
    datos: HorarioIn,
    sesion: Session = Depends(obtener_sesion),
    usuario: UsuarioORM = Depends(requerir_permiso(Permiso.REGISTRAR_HORAS)),
):
    try:
        tramos, total, advertencias = servicios.previsualizar(
            sesion, usuario.id, datos.fecha, datos.hora_inicio, datos.hora_fin
        )
    except DominioError as exc:
        raise dominio_a_http(exc)
    return PrevisualizacionOut(
        tramos=[a_tramo_out(t) for t in tramos], total_minutos=total, advertencias=advertencias
    )


@router.post("/solicitar", response_model=NovedadOut, status_code=status.HTTP_201_CREATED)
def solicitar(
    datos: SolicitudIn,
    request: Request,
    sesion: Session = Depends(obtener_sesion),
    usuario: UsuarioORM = Depends(requerir_permiso(Permiso.REGISTRAR_HORAS)),
):
    ip = request.client.host if request.client else None
    try:
        novedad = servicios.solicitar_novedad(
            sesion,
            usuario,
            datos.fecha,
            datos.hora_inicio,
            datos.hora_fin,
            datos.justificacion,
            ip,
            solicitante_id=datos.solicitante_id,
            observacion_adicional=datos.observacion_adicional,
        )
    except DominioError as exc:
        raise dominio_a_http(exc)
    return a_novedad_out(novedad, colaborador=usuario)


@router.get("/mias", response_model=list[NovedadOut])
def mis_novedades(
    sesion: Session = Depends(obtener_sesion),
    usuario: UsuarioORM = Depends(requerir_permiso(Permiso.REGISTRAR_HORAS)),
):
    novedades = repo.novedades_propias(sesion, usuario.id)
    return [a_novedad_out(n, colaborador=usuario) for n in novedades]


@router.patch("/{novedad_id}", response_model=NovedadOut)
def editar(
    novedad_id: int,
    datos: SolicitudEditIn,
    request: Request,
    sesion: Session = Depends(obtener_sesion),
    usuario: UsuarioORM = Depends(requerir_permiso(Permiso.REGISTRAR_HORAS)),
):
    ip = request.client.host if request.client else None
    cambios = {k: v for k, v in datos.model_dump().items() if v is not None}
    try:
        novedad = servicios.editar_novedad(sesion, usuario, novedad_id, cambios, ip)
    except DominioError as exc:
        raise dominio_a_http(exc)
    return a_novedad_out(novedad, colaborador=usuario)


@router.delete("/{novedad_id}", status_code=status.HTTP_204_NO_CONTENT)
def cancelar(
    novedad_id: int,
    request: Request,
    sesion: Session = Depends(obtener_sesion),
    usuario: UsuarioORM = Depends(requerir_permiso(Permiso.REGISTRAR_HORAS)),
):
    ip = request.client.host if request.client else None
    try:
        servicios.cancelar_novedad(sesion, usuario, novedad_id, ip)
    except DominioError as exc:
        raise dominio_a_http(exc)
