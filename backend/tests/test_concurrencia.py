"""Pruebas de concurrencia: múltiples operativos registrando al fin del turno."""
from __future__ import annotations

import threading
from concurrent.futures import ThreadPoolExecutor
from datetime import date, timedelta

from tests.conftest import auth_op


def _dia_libre() -> date:
    candidato = date.today() + timedelta(days=4)
    if candidato.day > 15:
        candidato = date(candidato.year, candidato.month, 15)
    return candidato


def test_solapamiento_concurrente_admite_un_solo_ganador(cliente):
    headers = auth_op(cliente)
    dia = _dia_libre().isoformat()
    carga = {
        "fecha": dia,
        "hora_inicio": "18:00",
        "hora_fin": "20:00",
        "solicitante_id": 1, "justificacion": "Registro simultáneo al terminar turno",
    }
    barrera = threading.Barrier(2)

    def enviar(_: int):
        barrera.wait()
        return cliente.post("/api/horas-extra/solicitar", json=carga, headers=headers)

    with ThreadPoolExecutor(max_workers=2) as ejecutor:
        resultados = list(ejecutor.map(enviar, range(2)))

    codigos = sorted(r.status_code for r in resultados)
    assert codigos == [201, 409], [(r.status_code, r.text) for r in resultados]
    perdedor = [r for r in resultados if r.status_code == 409][0]
    assert perdedor.json()["detail"]["codigo"] == "TRAMOS_SOLAPADOS"


def test_operativos_distintos_misma_ventana_todos_registran(cliente):
    dia = _dia_libre().isoformat()

    def enviar(codigo: str):
        headers = auth_op(cliente, codigo)
        return cliente.post(
            "/api/horas-extra/solicitar",
            json={
                "fecha": dia,
                "hora_inicio": "18:00",
                "hora_fin": "20:00",
                "solicitante_id": 1, "justificacion": f"Turno de {codigo} en paralelo",
            },
            headers=headers,
        )

    with ThreadPoolExecutor(max_workers=2) as ejecutor:
        resultados = list(ejecutor.map(enviar, ["LUISA", "YORLADIS"]))

    assert all(r.status_code == 201 for r in resultados), [
        (r.status_code, r.text) for r in resultados
    ]


def test_aprobaciones_masivas_concurrentes_no_duplican_estado(cliente):
    from tests.conftest import auth_jefe

    headers_op = auth_op(cliente)
    headers_jefe = auth_jefe(cliente)
    dia = _dia_libre().isoformat()
    creada = cliente.post(
        "/api/horas-extra/solicitar",
        json={"fecha": dia, "hora_inicio": "18:00", "hora_fin": "19:00", "solicitante_id": 1, "justificacion": "Carrera de aprobación"},
        headers=headers_op,
    ).json()
    novedad_id = creada["id"]
    barrera = threading.Barrier(2)

    def aprobar(_: int):
        barrera.wait()
        return cliente.patch(f"/api/rh/solicitudes/{novedad_id}/aprobar", json={}, headers=headers_jefe)

    with ThreadPoolExecutor(max_workers=2) as ejecutor:
        resultados = list(ejecutor.map(aprobar, range(2)))

    codigos = sorted(r.status_code for r in resultados)
    assert 200 in codigos
    assert 409 in codigos
    assert codigos == [200, 409]
