"""Infraestructura de persistencia: engine y sesiones SQLAlchemy 2.x.

SQLite en desarrollo; PostgreSQL en producción vía GHE_DATABASE_URL sin
cambios en dominio ni repositorios.
"""
from __future__ import annotations

from sqlalchemy import create_engine, event
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from app.core.config import CONFIG


class Base(DeclarativeBase):
    pass


def _sqlite_args(url: str) -> dict:
    return {"check_same_thread": False} if url.startswith("sqlite") else {}


def _adjuntar_pragmas(engine) -> None:
    if not engine.url.drivername.startswith("sqlite"):
        return

    @event.listens_for(engine, "connect")
    def _pragmas(dbapi_connection, _record):  # noqa: ANN001
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA foreign_keys=ON")
        cursor.execute("PRAGMA busy_timeout=5000")
        cursor.execute("PRAGMA journal_mode=WAL")
        cursor.close()


engine = create_engine(CONFIG.database_url, connect_args=_sqlite_args(CONFIG.database_url), future=True)
_adjuntar_pragmas(engine)
FabricaSesiones = sessionmaker(bind=engine, expire_on_commit=False, future=True)


def configurar_engine(url: str) -> None:
    """Reconfigura el engine global (usado por pruebas para DBs aisladas)."""
    global engine, FabricaSesiones
    engine.dispose()
    engine = create_engine(url, connect_args=_sqlite_args(url), future=True)
    _adjuntar_pragmas(engine)
    FabricaSesiones = sessionmaker(bind=engine, expire_on_commit=False, future=True)


def abrir_sesion() -> Session:
    return FabricaSesiones()
