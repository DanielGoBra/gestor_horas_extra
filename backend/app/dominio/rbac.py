"""RBAC: roles y permisos del Gestor de Horas Extra.

OPERATIVO          registra sus horas.
JEFE_OPERACIONES   evalúa, aprueba o rechaza.
RH                 solo descarga el consolidado Excel/CSV.
ADMIN              acceso total de soporte.
"""
from __future__ import annotations


class Rol:
    OPERATIVO = "OPERATIVO"
    JEFE_OPERACIONES = "JEFE_OPERACIONES"
    RH = "RH"
    ADMIN = "ADMIN"


class Permiso:
    REGISTRAR_HORAS = "registrar_horas"
    APROBAR_HORAS = "aprobar_horas"
    VER_BANDEJA = "ver_bandeja"
    EXPORTAR_NOMINA = "exportar_nomina"
    GESTIONAR_PERIODOS = "gestionar_periodos"
    GESTIONAR_CATALOGOS = "gestionar_catalogos"


_MATRIZ: dict[str, frozenset[str]] = {
    Permiso.REGISTRAR_HORAS: frozenset({Rol.OPERATIVO, Rol.ADMIN}),
    Permiso.APROBAR_HORAS: frozenset({Rol.JEFE_OPERACIONES, Rol.ADMIN}),
    Permiso.VER_BANDEJA: frozenset({Rol.JEFE_OPERACIONES, Rol.RH, Rol.ADMIN}),
    Permiso.EXPORTAR_NOMINA: frozenset({Rol.RH, Rol.ADMIN}),
    Permiso.GESTIONAR_PERIODOS: frozenset({Rol.JEFE_OPERACIONES, Rol.ADMIN}),
    Permiso.GESTIONAR_CATALOGOS: frozenset({Rol.JEFE_OPERACIONES, Rol.ADMIN}),
}


def roles_de(permiso: str) -> tuple[str, ...]:
    return tuple(sorted(_MATRIZ.get(permiso, frozenset())))


def tiene_permiso(rol: str, permiso: str) -> bool:
    return rol in _MATRIZ.get(permiso, frozenset())
