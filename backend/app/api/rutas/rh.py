"""Bandeja de aprobación (jefe de operaciones) y liquidación (RRHH)."""
from __future__ import annotations

import csv
import io
from datetime import date

from fastapi import APIRouter, Depends, Request, Response, status
from sqlalchemy.orm import Session

from app.api import servicios
from app.api.dependencias import obtener_sesion, requerir_permiso
from app.api.errores import dominio_a_http
from app.api.esquemas import (
    AprobacionIn,
    AprobacionMasivaIn,
    NovedadOut,
    PeriodoIn,
    PeriodoOut,
    RechazoIn,
)
from app.api.presentacion import a_novedad_out
from app.dominio.entidades import EstadoNovedad
from app.dominio.excepciones import DominioError
from app.dominio.rbac import Permiso
from app.infra import repositorios as repo
from app.api.exportacion import CABECERAS_EXCEL, fila_excel
from app.infra.modelos import UsuarioORM

router = APIRouter(prefix="/api/rh", tags=["Aprobacion y Liquidacion"])


@router.get("/pendientes", response_model=list[NovedadOut])
def pendientes(
    sesion: Session = Depends(obtener_sesion),
    _: UsuarioORM = Depends(requerir_permiso(Permiso.VER_BANDEJA)),
):
    pares = repo.bandeja_rh(sesion, estados=[EstadoNovedad.PENDIENTE_APROBACION.value])
    return [a_novedad_out(n, colaborador=u) for n, u in pares]


@router.get("/solicitudes", response_model=list[NovedadOut])
def bandeja(
    desde: date | None = None,
    hasta: date | None = None,
    area: str | None = None,
    colaborador_id: int | None = None,
    estado: str | None = None,
    sesion: Session = Depends(obtener_sesion),
    _: UsuarioORM = Depends(requerir_permiso(Permiso.VER_BANDEJA)),
):
    estados = [estado] if estado else None
    pares = repo.bandeja_rh(
        sesion, estados=estados, desde=desde, hasta=hasta, area=area, colaborador_id=colaborador_id
    )
    return [a_novedad_out(n, colaborador=u) for n, u in pares]


@router.patch("/solicitudes/{novedad_id}/aprobar", response_model=NovedadOut)
def aprobar(
    novedad_id: int,
    datos: AprobacionIn,
    request: Request,
    sesion: Session = Depends(obtener_sesion),
    aprobador: UsuarioORM = Depends(requerir_permiso(Permiso.APROBAR_HORAS)),
):
    ip = request.client.host if request.client else None
    try:
        novedad = servicios.aprobar(sesion, aprobador, novedad_id, datos.observacion, ip)
    except DominioError as exc:
        raise dominio_a_http(exc)
    return a_novedad_out(novedad)


@router.patch("/solicitudes/{novedad_id}/rechazar", response_model=NovedadOut)
def rechazar(
    novedad_id: int,
    datos: RechazoIn,
    request: Request,
    sesion: Session = Depends(obtener_sesion),
    aprobador: UsuarioORM = Depends(requerir_permiso(Permiso.APROBAR_HORAS)),
):
    ip = request.client.host if request.client else None
    try:
        novedad = servicios.rechazar(sesion, aprobador, novedad_id, datos.observacion, ip)
    except DominioError as exc:
        raise dominio_a_http(exc)
    return a_novedad_out(novedad)


@router.post("/solicitudes/aprobar-masivo", response_model=list[int])
def aprobar_masivo(
    datos: AprobacionMasivaIn,
    request: Request,
    sesion: Session = Depends(obtener_sesion),
    aprobador: UsuarioORM = Depends(requerir_permiso(Permiso.APROBAR_HORAS)),
):
    ip = request.client.host if request.client else None
    try:
        return servicios.aprobar_masivo(sesion, aprobador, datos.ids, ip)
    except DominioError as exc:
        raise dominio_a_http(exc)


@router.get("/usuarios")
def listar_usuarios(
    sesion: Session = Depends(obtener_sesion),
    _: UsuarioORM = Depends(requerir_permiso(Permiso.VER_BANDEJA)),
):
    usuarios = repo.usuarios_todos(sesion)
    return [
        {"id": u.id, "codigo": u.codigo, "nombre": u.nombre, "correo": u.correo, "area": u.area, "rol": u.rol}
        for u in usuarios
    ]


@router.get("/periodos", response_model=list[PeriodoOut])
def periodos(
    sesion: Session = Depends(obtener_sesion),
    _: UsuarioORM = Depends(requerir_permiso(Permiso.VER_BANDEJA)),
):
    return [
        PeriodoOut(
            id=p.id,
            etiqueta=p.etiqueta,
            fecha_inicio=p.fecha_inicio,
            fecha_fin=p.fecha_fin,
            estado=p.estado,
            cerrado_en=p.cerrado_en,
        )
        for p in repo.periodos_todos(sesion)
    ]


@router.post("/periodos", response_model=PeriodoOut, status_code=status.HTTP_201_CREATED)
def crear_periodo(
    datos: PeriodoIn,
    sesion: Session = Depends(obtener_sesion),
    usuario: UsuarioORM = Depends(requerir_permiso(Permiso.GESTIONAR_PERIODOS)),
):
    try:
        periodo = servicios.crear_periodo(sesion, usuario, datos.etiqueta, datos.fecha_inicio, datos.fecha_fin)
    except DominioError as exc:
        raise dominio_a_http(exc)
    return PeriodoOut(
        id=periodo.id,
        etiqueta=periodo.etiqueta,
        fecha_inicio=periodo.fecha_inicio,
        fecha_fin=periodo.fecha_fin,
        estado=periodo.estado,
        cerrado_en=periodo.cerrado_en,
    )


@router.post("/periodos/{periodo_id}/cerrar")
def cerrar_periodo(
    periodo_id: int,
    sesion: Session = Depends(obtener_sesion),
    usuario: UsuarioORM = Depends(requerir_permiso(Permiso.GESTIONAR_PERIODOS)),
):
    try:
        periodo, congeladas = servicios.cerrar_periodo(sesion, usuario, periodo_id)
    except DominioError as exc:
        raise dominio_a_http(exc)
    return {
        "etiqueta": periodo.etiqueta,
        "estado": periodo.estado,
        "congeladas": len(congeladas),
        "ids_congelados": congeladas,
    }


@router.get("/periodos/{periodo_id}/exportar")
def exportar_periodo(
    periodo_id: int,
    sesion: Session = Depends(obtener_sesion),
    _: UsuarioORM = Depends(requerir_permiso(Permiso.EXPORTAR_NOMINA)),
):
    periodo = repo.periodo_por_id(sesion, periodo_id)
    if periodo is None:
        raise dominio_a_http(DominioError("Periodo no existe", codigo="NO_ENCONTRADO"))
    filas = repo.solicitudes_para_excel(sesion, periodo.fecha_inicio, periodo.fecha_fin)

    buffer = io.StringIO()
    writer = csv.writer(buffer)
    writer.writerow(CABECERAS_EXCEL)
    for solicitud, usuario in filas:
        writer.writerow(fila_excel(solicitud, usuario, list(solicitud.tramos)))
    contenido = "\ufeff" + buffer.getvalue()
    nombre = f"Registro de horas extras en operaciones {periodo.etiqueta}.csv"
    return Response(
        content=contenido,
        media_type="text/csv; charset=utf-8",
        headers={"Content-Disposition": f'attachment; filename="{nombre}"'},
    )
