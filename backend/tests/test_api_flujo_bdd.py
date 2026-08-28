"""Pruebas BDD de extremo a extremo sobre la API (escenarios del .feature)."""
from __future__ import annotations

import io
from datetime import date, timedelta

from tests.conftest import auth_jefe, auth_op, auth_rh, login


def _dia_libre() -> date:
    hoy = date.today()
    candidato = hoy + timedelta(days=3)
    if candidato.day > 15:
        candidato = date(candidato.year, candidato.month, 15)
    return candidato


def test_operativo_registra_cruce_diurno_nocturno_y_estado_pendiente(cliente):
    headers = auth_op(cliente)
    dia = _dia_libre()

    previa = cliente.post(
        "/api/horas-extra/previsualizar",
        json={"fecha": dia.isoformat(), "hora_inicio": "18:00", "hora_fin": "23:00"},
        headers=headers,
    )
    assert previa.status_code == 200
    cuerpo = previa.json()
    assert [(t["tipo_hora"], t["minutos"]) for t in cuerpo["tramos"]] == [
        ("EXTRA_DIURNA", 180),
        ("EXTRA_NOCTURNA", 120),
    ]

    respuesta = cliente.post(
        "/api/horas-extra/solicitar",
        json={
            "fecha": dia.isoformat(),
            "hora_inicio": "18:00",
            "hora_fin": "23:00",
            "solicitante_id": 1, "justificacion": "Inventario trimestral de bodega central",
        },
        headers=headers,
    )
    assert respuesta.status_code == 201, respuesta.text
    novedad = respuesta.json()
    assert novedad["estado"] == "PENDIENTE_APROBACION"
    assert len(novedad["tramos"]) == 2
    assert novedad["total_minutos"] == 300


def test_tramos_solapados_rechazados(cliente):
    headers = auth_op(cliente)
    dia = _dia_libre()
    carga = {
        "hora_inicio": "18:00",
        "hora_fin": "20:00",
        "solicitante_id": 1, "justificacion": "Soporte despacho turno noche",
    }
    ok = cliente.post("/api/horas-extra/solicitar", json={"fecha": dia.isoformat(), **carga}, headers=headers)
    assert ok.status_code == 201
    solape = cliente.post(
        "/api/horas-extra/solicitar", json={"fecha": dia.isoformat(), "hora_inicio": "19:00", "hora_fin": "21:00", "solicitante_id": 1, "justificacion": "Segundo intento solapado"},
        headers=headers,
    )
    assert solape.status_code == 409
    assert solape.json()["detail"]["codigo"] == "TRAMOS_SOLAPADOS"


def test_tope_diario_excedido_bloquea(cliente, monkeypatch):
    from app.core import config

    monkeypatch.setattr(config, "BLOQUEAR_TOPES", True)
    headers = auth_op(cliente)
    dia = _dia_libre()
    respuesta = cliente.post(
        "/api/horas-extra/solicitar",
        json={"fecha": dia.isoformat(), "hora_inicio": "18:00", "hora_fin": "21:30", "solicitante_id": 1, "justificacion": "Mantenimiento mayor de línea"},
        headers=headers,
    )
    assert respuesta.status_code == 409
    assert respuesta.json()["detail"]["codigo"] == "TOPE_DIARIO_EXCEDIDO"


def test_aprobacion_flujo_jefe_operaciones_y_edicion_bloqueada(cliente):
    headers_op = auth_op(cliente)
    headers_jefe = auth_jefe(cliente)
    dia = _dia_libre()
    creada = cliente.post(
        "/api/horas-extra/solicitar",
        json={"fecha": dia.isoformat(), "hora_inicio": "18:00", "hora_fin": "19:30", "solicitante_id": 1, "justificacion": "Despacho extraordinario"},
        headers=headers_op,
    ).json()

    pendientes = cliente.get("/api/rh/pendientes", headers=headers_jefe).json()
    assert any(p["id"] == creada["id"] for p in pendientes)

    aprobada = cliente.patch(f"/api/rh/solicitudes/{creada['id']}/aprobar", json={"observacion": None}, headers=headers_jefe)
    assert aprobada.status_code == 200
    assert aprobada.json()["estado"] == "APROBADA"

    avisos = cliente.get("/api/notificaciones", headers=headers_op).json()
    assert avisos, "la operativa debe recibir notificación al aprobar"
    assert avisos[0]["leida"] is False
    assert "Aprobado" in avisos[0]["mensaje"]

    intento = cliente.patch(
        f"/api/horas-extra/{creada['id']}",
        json={"hora_fin": "20:00"},
        headers=headers_op,
    )
    assert intento.status_code == 409
    assert intento.json()["detail"]["codigo"] == "ESTADO_INVALIDO"


def test_rechazo_exige_observacion(cliente):
    headers_op = auth_op(cliente)
    headers_jefe = auth_jefe(cliente)
    dia = _dia_libre()
    creada = cliente.post(
        "/api/horas-extra/solicitar",
        json={"fecha": dia.isoformat(), "hora_inicio": "18:00", "hora_fin": "19:00", "solicitante_id": 1, "justificacion": "Apoyo logístico"},
        headers=headers_op,
    ).json()
    rechazo = cliente.patch(f"/api/rh/solicitudes/{creada['id']}/rechazar", json={"observacion": ""}, headers=headers_jefe)
    assert rechazo.status_code == 422
    assert rechazo.json()["detail"]["codigo"] == "OBSERVACION_REQUERIDA"

    rechazo_ok = cliente.patch(
        f"/api/rh/solicitudes/{creada['id']}/rechazar",
        json={"observacion": "Sin autorización del jefe de turno"},
        headers=headers_jefe,
    )
    assert rechazo_ok.json()["estado"] == "RECHAZADA"


def test_periodo_cerrado_congela_e_impide_editar(cliente):
    headers_op = auth_op(cliente)
    headers_jefe = auth_jefe(cliente)
    headers_rh = auth_rh(cliente)
    dia = _dia_libre()
    pendiente = cliente.post(
        "/api/horas-extra/solicitar",
        json={"fecha": dia.isoformat(), "hora_inicio": "18:00", "hora_fin": "19:00", "solicitante_id": 1, "justificacion": "Cierre contable de planta"},
        headers=headers_op,
    )
    assert pendiente.status_code == 201
    pendiente_id = pendiente.json()["id"]

    aprobada = cliente.post(
        "/api/horas-extra/solicitar",
        json={"fecha": dia.isoformat(), "hora_inicio": "20:00", "hora_fin": "22:00", "solicitante_id": 1, "justificacion": "Turno nocturno especial"},
        headers=auth_op(cliente, "YORLADIS"),
    )
    assert aprobada.status_code == 201
    aprobada_id = aprobada.json()["id"]
    cliente.patch(f"/api/rh/solicitudes/{aprobada_id}/aprobar", json={}, headers=headers_jefe)

    periodo = cliente.post(
        "/api/rh/periodos",
        json={"etiqueta": "2026-TEST-Q1", "fecha_inicio": dia.isoformat(), "fecha_fin": dia.isoformat()},
        headers=headers_jefe,
    )
    assert periodo.status_code == 201, periodo.text
    periodo_id = periodo.json()["id"]

    cierre = cliente.post(f"/api/rh/periodos/{periodo_id}/cerrar", headers=headers_jefe)
    assert cierre.status_code == 200, cierre.text
    assert cierre.json()["congeladas"] >= 1

    edicion_bajo_cierre = cliente.patch(
        f"/api/horas-extra/{pendiente_id}", json={"solicitante_id": 1, "justificacion": "Intento tras cierre"}, headers=headers_op
    )
    assert edicion_bajo_cierre.status_code == 409
    assert edicion_bajo_cierre.json()["detail"]["codigo"] == "PERIODO_CONTABLE_CERRADO"

    export = cliente.get(f"/api/rh/periodos/{periodo_id}/exportar", headers=headers_rh)
    assert export.status_code == 200
    lineas = io.StringIO(export.text).read().lstrip("\ufeff").strip().splitlines()
    assert lineas[0].startswith("Id")
    assert any("Yorladis" in l for l in lineas[1:])


def test_operativo_no_accede_a_bandeja_rh(cliente):
    headers = auth_op(cliente)
    respuesta = cliente.get("/api/rh/pendientes", headers=headers)
    assert respuesta.status_code == 403
    assert respuesta.json()["detail"]["codigo"] == "PERMISO_DENEGADO"


def test_aprobar_masivo_es_atomico(cliente):
    headers_op = auth_op(cliente)
    headers_jefe = auth_jefe(cliente)
    dia = _dia_libre()
    a = cliente.post(
        "/api/horas-extra/solicitar",
        json={"fecha": dia.isoformat(), "hora_inicio": "18:00", "hora_fin": "19:00", "solicitante_id": 1, "justificacion": "Lote A masivo"},
        headers=headers_op,
    ).json()
    b = cliente.post(
        "/api/horas-extra/solicitar",
        json={"fecha": dia.isoformat(), "hora_inicio": "20:00", "hora_fin": "21:00", "solicitante_id": 1, "justificacion": "Lote B masivo"},
        headers=headers_op,
    ).json()

    fallo = cliente.post("/api/rh/solicitudes/aprobar-masivo", json={"ids": [a["id"], 999999]}, headers=headers_jefe)
    assert fallo.status_code == 404
    estados = {n["id"]: n["estado"] for n in cliente.get("/api/horas-extra/mias", headers=headers_op).json()}
    assert estados[a["id"]] == "PENDIENTE_APROBACION"
    assert estados[b["id"]] == "PENDIENTE_APROBACION"

    exitoso = cliente.post("/api/rh/solicitudes/aprobar-masivo", json={"ids": [a["id"], b["id"]]}, headers=headers_jefe)
    assert sorted(exitoso.json()) == sorted([a["id"], b["id"]])


def test_credenciales_invalidas(cliente):
    respuesta = cliente.post("/api/auth/login", json={"codigo": "LUISA", "password": "incorrecta"})
    assert respuesta.status_code == 401
    assert respuesta.json()["detail"]["codigo"] == "CREDENCIALES_INVALIDAS"
