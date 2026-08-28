"""Seguridad IAM: hashing PBKDF2-HMAC-SHA256 y tokens JWT firmados."""
from __future__ import annotations

import hashlib
import hmac
import secrets
from datetime import datetime, timedelta, timezone

import jwt

from app.core.config import CONFIG
from app.dominio.excepciones import CredencialesInvalidas

_ITERACIONES = 200_000


def hash_password(password: str) -> str:
    salt = secrets.token_hex(16)
    digesto = hashlib.pbkdf2_hmac("sha256", password.encode(), bytes.fromhex(salt), _ITERACIONES)
    return f"pbkdf2_sha256${_ITERACIONES}${salt}${digesto.hex()}"


def verificar_password(password: str, almacenado: str) -> bool:
    try:
        _, iteraciones, salt, esperado = almacenado.split("$")
        calculado = hashlib.pbkdf2_hmac(
            "sha256", password.encode(), bytes.fromhex(salt), int(iteraciones)
        )
        return hmac.compare_digest(calculado.hex(), esperado)
    except (ValueError, TypeError):
        return False


def crear_token(usuario_id: int, codigo: str, rol: str) -> str:
    ahora = datetime.now(timezone.utc)
    payload = {
        "sub": str(usuario_id),
        "codigo": codigo,
        "rol": rol,
        "iat": ahora,
        "exp": ahora + timedelta(hours=CONFIG.jwt_horas_vigencia),
    }
    return jwt.encode(payload, CONFIG.jwt_secret, algorithm=CONFIG.jwt_algoritmo)


def decodificar_token(token: str) -> dict:
    try:
        return jwt.decode(token, CONFIG.jwt_secret, algorithms=[CONFIG.jwt_algoritmo])
    except jwt.ExpiredSignatureError as exc:
        raise CredencialesInvalidas("TOKEN_EXPIRADO") from exc
    except jwt.InvalidTokenError as exc:
        raise CredencialesInvalidas("TOKEN_INVALIDO") from exc
