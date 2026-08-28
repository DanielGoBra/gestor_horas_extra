"""Pruebas de seguridad IAM: hashing y JWT."""
from __future__ import annotations

from datetime import datetime, timedelta, timezone

import pytest

from app.core.seguridad import (
    crear_token,
    decodificar_token,
    hash_password,
    verificar_password,
)
from app.dominio.excepciones import CredencialesInvalidas


def test_hash_y_verificacion_password():
    almacenado = hash_password("opera450")
    assert almacenado.startswith("pbkdf2_sha256$")
    assert verificar_password("opera450", almacenado)
    assert not verificar_password("Opera450 ", almacenado)


def test_tokens_contienen_identidad_y_rol():
    token = crear_token(7, "OP-450", "OPERATIVO")
    payload = decodificar_token(token)
    assert payload["sub"] == "7"
    assert payload["codigo"] == "OP-450"
    assert payload["rol"] == "OPERATIVO"


def test_token_falsificado_rechazado():
    with pytest.raises(CredencialesInvalidas):
        decodificar_token("abc.def.ghi")
