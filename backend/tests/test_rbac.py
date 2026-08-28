"""RBAC: jefe de operaciones aprueba; RRHH solo exporta; jefes comerciales solicitan."""
from __future__ import annotations

from datetime import date, timedelta

from tests.conftest import auth_jefe, auth_op, auth_rh


def _dia_libre() -> date:
    candidato = date.today() + timedelta(days=6)
    if candidato.day > 15:
        candidato = date(candidato.year, candidato.month, 15)
    return candidato


def test_catalogo_solo_jefes_comerciales_activos(cliente):
    headers = auth_op(cliente)
    lista = cliente.get("/api/catalogos/solicitantes", headers=headers).json()
    nombres = [s["nombre"] for s in lista]
    assert "Hernán Darío Giraldo Carmona" in nombres
    assert "Natalia Ramírez Echavarría" in nombres
    assert all("Miguel" not in n for n in nombres)
    cargos = {s["nombre"]: s["cargo"] for s in lista}
    assert cargos["Hernán Darío Giraldo Carmona"] == "Jefe comercial"
    assert cargos["Natalia Ramírez Echavarría"] == "Jefe comercial"


def test_rh_puede_ver_bandeja_pero_no_aprobar(cliente):
    headers_op = auth_op(cliente)
    headers_rh = auth_rh(cliente)
    dia = _dia_libre()
    creada = cliente.post(
        "/api/horas-extra/solicitar",
        json={
            "fecha": dia.isoformat(),
            "hora_inicio": "18:00",
            "hora_fin": "19:00",
            "solicitante_id": 1,
            "justificacion": "Apoyo solicitado por jefe comercial",
        },
        headers=headers_op,
    )
    assert creada.status_code == 201
    novedad_id = creada.json()["id"]

    bandeja = cliente.get("/api/rh/pendientes", headers=headers_rh)
    assert bandeja.status_code == 200
    assert any(p["id"] == novedad_id for p in bandeja.json())

    aprobacion = cliente.patch(
        f"/api/rh/solicitudes/{novedad_id}/aprobar", json={}, headers=headers_rh
    )
    assert aprobacion.status_code == 403
    assert aprobacion.json()["detail"]["codigo"] == "PERMISO_DENEGADO"

    rechazo = cliente.patch(
        f"/api/rh/solicitudes/{novedad_id}/rechazar",
        json={"observacion": "RRHH no aprueba"},
        headers=headers_rh,
    )
    assert rechazo.status_code == 403

    periodo = cliente.post(
        "/api/rh/periodos",
        json={"etiqueta": "2026-RH-NO", "fecha_inicio": dia.isoformat(), "fecha_fin": dia.isoformat()},
        headers=headers_rh,
    )
    assert periodo.status_code == 403


def test_jefe_operaciones_aprueba_y_no_exporta(cliente):
    headers_op = auth_op(cliente)
    headers_jefe = auth_jefe(cliente)
    dia = _dia_libre()
    creada = cliente.post(
        "/api/horas-extra/solicitar",
        json={
            "fecha": dia.isoformat(),
            "hora_inicio": "18:00",
            "hora_fin": "19:00",
            "solicitante_id": 1,
            "justificacion": "Turno extra por vacaciones",
        },
        headers=headers_op,
    ).json()
    aprobada = cliente.patch(
        f"/api/rh/solicitudes/{creada['id']}/aprobar", json={}, headers=headers_jefe
    )
    assert aprobada.status_code == 200
    assert aprobada.json()["estado"] == "APROBADA"

    periodo = cliente.post(
        "/api/rh/periodos",
        json={"etiqueta": "2026-JEFE-Q", "fecha_inicio": dia.isoformat(), "fecha_fin": dia.isoformat()},
        headers=headers_jefe,
    )
    assert periodo.status_code == 201
    export = cliente.get(
        f"/api/rh/periodos/{periodo.json()['id']}/exportar", headers=headers_jefe
    )
    assert export.status_code == 403


def test_rh_exporta_excel_del_periodo(cliente):
    headers_op = auth_op(cliente)
    headers_jefe = auth_jefe(cliente)
    headers_rh = auth_rh(cliente)
    dia = _dia_libre()
    creada = cliente.post(
        "/api/horas-extra/solicitar",
        json={
            "fecha": dia.isoformat(),
            "hora_inicio": "18:00",
            "hora_fin": "19:00",
            "solicitante_id": 1,
            "justificacion": "Cierre de cartera",
        },
        headers=headers_op,
    ).json()
    cliente.patch(f"/api/rh/solicitudes/{creada['id']}/aprobar", json={}, headers=headers_jefe)
    periodo = cliente.post(
        "/api/rh/periodos",
        json={"etiqueta": "2026-RH-CSV", "fecha_inicio": dia.isoformat(), "fecha_fin": dia.isoformat()},
        headers=headers_jefe,
    )
    assert periodo.status_code == 201
    export = cliente.get(
        f"/api/rh/periodos/{periodo.json()['id']}/exportar", headers=headers_rh
    )
    assert export.status_code == 200
    assert "text/csv" in export.headers["content-type"]


def test_jefe_operaciones_no_registra_horas(cliente):
    headers_jefe = auth_jefe(cliente)
    dia = _dia_libre()
    respuesta = cliente.post(
        "/api/horas-extra/solicitar",
        json={
            "fecha": dia.isoformat(),
            "hora_inicio": "18:00",
            "hora_fin": "19:00",
            "solicitante_id": 1,
            "justificacion": "El jefe no registra",
        },
        headers=headers_jefe,
    )
    assert respuesta.status_code == 403
