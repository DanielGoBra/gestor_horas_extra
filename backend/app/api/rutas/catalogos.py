"""Catálogos compartidos: solicitantes y reglas laborales (ventanas diurna/nocturna)."""
from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.dependencias import obtener_sesion, requerir_permiso, usuario_actual
from app.api.errores import dominio_a_http
from app.api.esquemas import (
    ReglasLaboralesIn,
    ReglasLaboralesOut,
    SolicitanteIn,
    SolicitanteOut,
)
from app.dominio.excepciones import DominioError
from app.dominio.rbac import Permiso
from app.infra import auditoria
from app.infra import repositorios as repo
from app.infra.modelos import UsuarioORM

router = APIRouter(prefix="/api", tags=["Catalogos"])


@router.get("/catalogos/solicitantes", response_model=list[SolicitanteOut])
def listar_solicitantes(
    sesion: Session = Depends(obtener_sesion),
    _: UsuarioORM = Depends(usuario_actual),
):
    return [
        SolicitanteOut(id=s.id, nombre=s.nombre, cargo=s.cargo)
        for s in repo.solicitantes_activos(sesion)
    ]


@router.post("/rh/solicitantes", response_model=SolicitanteOut, status_code=201)
def crear_solicitante(
    datos: SolicitanteIn,
    sesion: Session = Depends(obtener_sesion),
    rh: UsuarioORM = Depends(requerir_permiso(Permiso.GESTIONAR_CATALOGOS)),
):
    fila = repo.crear_solicitante(sesion, datos.nombre, datos.cargo)
    auditoria.registrar(
        sesion, rh.id, "CREAR_SOLICITANTE", valores_nuevos={"nombre": fila.nombre}
    )
    sesion.commit()
    return SolicitanteOut(id=fila.id, nombre=fila.nombre, cargo=fila.cargo)


@router.get("/config/reglas", response_model=ReglasLaboralesOut)
def leer_reglas(
    sesion: Session = Depends(obtener_sesion),
    _: UsuarioORM = Depends(usuario_actual),
):
    params = repo.parametros_vigentes(sesion)
    return ReglasLaboralesOut(
        inicio_diurna=params.inicio_diurna.strftime("%H:%M"),
        inicio_nocturna=params.fin_diurna.strftime("%H:%M"),
        tope_horas_diarias=params.tope_minutos_diarios // 60,
        tope_horas_semanales=params.tope_minutos_semanales // 60,
    )


@router.patch("/rh/config/reglas", response_model=ReglasLaboralesOut)
def actualizar_reglas(
    datos: ReglasLaboralesIn,
    sesion: Session = Depends(obtener_sesion),
    rh: UsuarioORM = Depends(requerir_permiso(Permiso.GESTIONAR_CATALOGOS)),
):
    try:
        repo.guardar_parametros(sesion, datos.inicio_diurna, datos.inicio_nocturna)
        auditoria.registrar(
            sesion,
            rh.id,
            "ACTUALIZAR_REGLAS",
            valores_nuevos={
                "inicio_diurna": datos.inicio_diurna,
                "inicio_nocturna": datos.inicio_nocturna,
            },
        )
        sesion.commit()
    except DominioError as exc:
        raise dominio_a_http(exc)
    params = repo.parametros_vigentes(sesion)
    return ReglasLaboralesOut(
        inicio_diurna=params.inicio_diurna.strftime("%H:%M"),
        inicio_nocturna=params.fin_diurna.strftime("%H:%M"),
        tope_horas_diarias=params.tope_minutos_diarios // 60,
        tope_horas_semanales=params.tope_minutos_semanales // 60,
    )
