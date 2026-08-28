"""Motor de Reglas Laborales: clasificación pura de tramos y topes legales.

Fuente única de verdad para determinar si un minuto trabajado es
EXTRA_DIURNA, EXTRA_NOCTURNA o DOMINICAL_FESTIVA.
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime, time, timedelta
from enum import Enum


class TipoHora(str, Enum):
    EXTRA_DIURNA = "EXTRA_DIURNA"
    EXTRA_NOCTURNA = "EXTRA_NOCTURNA"
    DOMINICAL_FESTIVA = "DOMINICAL_FESTIVA"


@dataclass(frozen=True)
class ParametrosReglas:
    inicio_diurna: time = time(6, 0)
    fin_diurna: time = time(21, 0)
    tope_minutos_diarios: int = 120
    tope_minutos_semanales: int = 720


DEFAULT = ParametrosReglas()


class IntervaloInvalido(ValueError):
    pass


def normalizar_intervalo(
    fecha_trabajo: date, hora_inicio: time, hora_fin: time
) -> tuple[datetime, datetime]:
    ini = datetime.combine(fecha_trabajo, hora_inicio)
    fin = datetime.combine(fecha_trabajo, hora_fin)
    if hora_fin <= hora_inicio:
        fin += timedelta(days=1)
    if fin - ini >= timedelta(hours=24):
        raise IntervaloInvalido("El intervalo debe ser menor a 24 horas")
    return ini, fin


def es_domingo_o_festivo(d: date, festivos: frozenset[date] | set[date]) -> bool:
    return d.weekday() == 6 or d in festivos


def _clasificar_segmento(
    ini: datetime, fin: datetime, festivos: frozenset[date], params: ParametrosReglas
) -> TipoHora:
    medio = ini + (fin - ini) / 2
    if es_domingo_o_festivo(medio.date(), festivos):
        return TipoHora.DOMINICAL_FESTIVA
    t = medio.time()
    if params.inicio_diurna <= t < params.fin_diurna:
        return TipoHora.EXTRA_DIURNA
    return TipoHora.EXTRA_NOCTURNA


@dataclass(frozen=True)
class TramoCalculado:
    inicio_dt: datetime
    fin_dt: datetime
    tipo_hora: TipoHora

    @property
    def minutos(self) -> int:
        return int((self.fin_dt - self.inicio_dt).total_seconds() // 60)

    @property
    def horas(self) -> float:
        return round(self.minutos / 60.0, 2)


def calcular_tramos(
    fecha_trabajo: date,
    hora_inicio: time,
    hora_fin: time,
    festivos: frozenset[date] | set[date] = frozenset(),
    params: ParametrosReglas = DEFAULT,
) -> list[TramoCalculado]:
    """Divide el intervalo en tramos homogéneos según ventanas y calendario."""
    ini, fin = normalizar_intervalo(fecha_trabajo, hora_inicio, hora_fin)
    cortes: set[datetime] = set()
    dia = (ini - timedelta(days=1)).date()
    limite = (fin + timedelta(days=1)).date()
    while dia <= limite:
        medianoche = datetime.combine(dia, time(0, 0))
        for candidato in (
            medianoche,
            datetime.combine(dia, params.inicio_diurna),
            datetime.combine(dia, params.fin_diurna),
        ):
            if ini < candidato < fin:
                cortes.add(candidato)
        dia += timedelta(days=1)

    puntos = [ini, *sorted(cortes), fin]
    tramos: list[TramoCalculado] = []
    for a, b in zip(puntos, puntos[1:]):
        tipo = _clasificar_segmento(a, b, festivos, params)
        if tramos and tramos[-1].tipo_hora == tipo and tramos[-1].fin_dt == a:
            previo = tramos[-1]
            tramos[-1] = TramoCalculado(previo.inicio_dt, b, tipo)
        else:
            tramos.append(TramoCalculado(a, b, tipo))
    return tramos


def minutos_por_fecha(tramos: list[TramoCalculado]) -> dict[date, int]:
    totales: dict[date, int] = {}
    for tramo in tramos:
        restantes = int((tramo.fin_dt - tramo.inicio_dt).total_seconds() // 60)
        cursor = tramo.inicio_dt
        while restantes > 0:
            siguiente_medianoche = datetime.combine(
                cursor.date() + timedelta(days=1), time(0, 0)
            )
            disponible = int((siguiente_medianoche - cursor).total_seconds() // 60)
            consumido = min(disponible, restantes)
            totales[cursor.date()] = totales.get(cursor.date(), 0) + consumido
            restantes -= consumido
            cursor = siguiente_medianoche
    return totales


def total_minutos(tramos: list[TramoCalculado]) -> int:
    return sum(int((t.fin_dt - t.inicio_dt).total_seconds() // 60) for t in tramos)


def semana_iso(f: date) -> tuple[int, int]:
    iso = f.isocalendar()
    return iso[0], iso[1]


def intervalos_solapan(a_ini: datetime, a_fin: datetime, b_ini: datetime, b_fin: datetime) -> bool:
    return a_ini < b_fin and b_ini < a_fin
