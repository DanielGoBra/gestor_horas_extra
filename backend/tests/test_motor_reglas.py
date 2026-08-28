"""Pruebas del Motor de Reglas (puro, sin I/O). Escenarios del .feature."""
from __future__ import annotations

from datetime import date, time

import pytest

from app.dominio.motor_reglas import (
    DEFAULT,
    IntervaloInvalido,
    TipoHora,
    calcular_tramos,
    minutos_por_fecha,
    normalizar_intervalo,
    total_minutos,
)

DOMINGO = date(2026, 8, 16)
LUNES = date(2026, 8, 17)


def tipos(tramos):
    return [(t.tipo_hora, t.inicio_dt.strftime("%H:%M"), t.fin_dt.strftime("%H:%M")) for t in tramos]


class TestEscenarioBDDDiurnaNocturna:
    def test_18_a_23_divide_en_diurna_y_nocturna(self):
        tramos = calcular_tramos(date(2026, 8, 10), time(18, 0), time(23, 0))
        assert tipos(tramos) == [
            (TipoHora.EXTRA_DIURNA, "18:00", "21:00"),
            (TipoHora.EXTRA_NOCTURNA, "21:00", "23:00"),
        ]
        assert total_minutos(tramos) == 300

    def test_estado_inicial_pendiente_se_valida_en_capa_agregado(self):
        pass


class TestCruceMedianoche:
    def test_23_a_01_es_un_solo_tramo_nocturno(self):
        tramos = calcular_tramos(LUNES, time(23, 0), time(1, 0))
        assert tipos(tramos) == [(TipoHora.EXTRA_NOCTURNA, "23:00", "01:00")]
        assert total_minutos(tramos) == 120

    def test_cruce_desde_domingo_segmenta_por_fecha_calendario(self):
        festivos = frozenset()
        tramos = calcular_tramos(DOMINGO, time(22, 0), time(2, 0), festivos)
        assert tipos(tramos) == [
            (TipoHora.DOMINICAL_FESTIVA, "22:00", "00:00"),
            (TipoHora.EXTRA_NOCTURNA, "00:00", "02:00"),
        ]

    def test_intervalo_de_24h_exactas_invalido(self):
        with pytest.raises(IntervaloInvalido):
            normalizar_intervalo(DOMINGO, time(1, 0), time(1, 0))


class TestDominicalFestiva:
    def test_domingo_completo_es_festivo(self):
        tramos = calcular_tramos(DOMINGO, time(10, 0), time(13, 0))
        assert tipos(tramos) == [(TipoHora.DOMINICAL_FESTIVA, "10:00", "13:00")]

    def test_fecha_en_tabla_festivos_es_festiva_incluso_entre_semana(self):
        festivos = frozenset({date(2026, 8, 7)})
        tramos = calcular_tramos(date(2026, 8, 7), time(9, 0), time(11, 0), festivos)
        assert tipos(tramos) == [(TipoHora.DOMINICAL_FESTIVA, "09:00", "11:00")]


class TestVentanasConfigurables:
    def test_nocturna_que_empieza_las_20_con_fin_diurna_21(self):
        from app.dominio.motor_reglas import ParametrosReglas

        params = ParametrosReglas(fin_diurna=time(19, 0))
        tramos = calcular_tramos(LUNES, time(18, 0), time(20, 0), frozenset(), params)
        assert tipos(tramos) == [
            (TipoHora.EXTRA_DIURNA, "18:00", "19:00"),
            (TipoHora.EXTRA_NOCTURNA, "19:00", "20:00"),
        ]


class TestMinutosPorFecha:
    def test_reparte_por_medianoche_para_topes(self):
        tramos = calcular_tramos(DOMINGO, time(23, 0), time(1, 0))
        reparto = minutos_por_fecha(tramos)
        assert reparto[DOMINGO] == 60
        assert reparto[date(2026, 8, 17)] == 60

    def test_total_consistente(self):
        tramos = calcular_tramos(LUNES, time(18, 0), time(23, 0))
        assert total_minutos(tramos) == sum(minutos_por_fecha(tramos).values())
