"""Punto de entrada FastAPI del Gestor de Horas Extra."""
from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.errores import dominio_a_http
from app.api.rutas import auth, catalogos, horas_extra, notificaciones, rh
from app.dominio.excepciones import DominioError
from app.infra import semilla


@asynccontextmanager
async def lifespan(_: FastAPI):
    semilla.inicializar()
    yield


def crear_app() -> FastAPI:
    app = FastAPI(
        title="API Gestor de Horas Extra",
        description=(
            "Plataforma de registro, aprobación y liquidación de horas extraordinarias. "
            "Contextos: IAM, Registro/Novedades, Aprobación/Auditoría y Liquidación."
        ),
        version="1.0.0",
        lifespan=lifespan,
    )
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_methods=["*"],
        allow_headers=["*"],
    )
    app.include_router(auth.router)
    app.include_router(horas_extra.router)
    app.include_router(rh.router)
    app.include_router(catalogos.router)
    app.include_router(notificaciones.router)

    @app.exception_handler(DominioError)
    async def _dominio(_, exc: DominioError):
        raise dominio_a_http(exc)

    @app.get("/health", tags=["Operacion"])
    def salud():
        return {"estado": "OK", "servicio": "gestor-horas-extra"}

    return app


app = crear_app()
