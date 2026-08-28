"""Fixtures compartidas: BD aislada por prueba + cliente HTTP + helpers de login."""
from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from app.infra import db as infra_db
from app.infra import semilla


@pytest.fixture()
def cliente(tmp_path):
    url = f"sqlite:///{(tmp_path / 'test.db').as_posix()}"
    infra_db.configurar_engine(url)
    from app.main import app

    semilla.inicializar(solo_si_vacio=False)
    with TestClient(app) as c:
        yield c


def login(cliente: TestClient, codigo: str, password: str) -> dict:
    respuesta = cliente.post("/api/auth/login", json={"codigo": codigo, "password": password})
    assert respuesta.status_code == 200, respuesta.text
    return {"Authorization": f"Bearer {respuesta.json()['access_token']}"}


def auth_op(cliente: TestClient, codigo: str = "LUISA") -> dict:
    claves = {"LUISA": "inklusiva", "YORLADIS": "inklusiva", "JOANNA": "inklusiva", "MARILUZ": "inklusiva"}
    return login(cliente, codigo, claves[codigo])


def auth_rh(cliente: TestClient) -> dict:
    return login(cliente, "ADRIANA", "inklusiva")


def auth_jefe(cliente: TestClient) -> dict:
    return login(cliente, "JEFEOP", "inklusiva")
