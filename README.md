# Gestor de Horas Extra

Plataforma de escritorio para el ingreso y registro de horas extraordinarias: captura por operativos, cálculo automático de recargos (diurna / nocturna / dominical-festiva), aprobación RH con bandeja filtrable y cortes quincenales inmutables para nómina.

Arquitectura según `docs/02_ADR_decisiones.md`:

```
┌──────────────────────┐   HTTPS/JSON+JWT   ┌─────────────────────────┐    ORM     ┌─────────────────────────┐
│  App Escritorio      │ ─────────────────► │  API Backend FastAPI    │ ─────────► │ SQLite (dev)            │
│  Flutter Desktop Win │ ◄───────────────── │  Reglas + Estados       │ ─────────► │ PostgreSQL (prod-ready) │
│  outbox offline      │                    │  Motor de Recargos      │            │ audit_log inmutable     │
└──────────────────────┘                    └─────────────────────────┘            └─────────────────────────┘
```

## Estructura

| Ruta | Contenido |
|---|---|
| `docs/01_lenguaje_ubicuo.md` | Glosario DDD canónico |
| `docs/02_ADR_decisiones.md` | ADR-001..003 |
| `docs/03_c4_contenedores.md` | Diagramas C4 nivel 2-3 |
| `docs/04_esquema_datos.md` | Modelo relacional |
| `docs/bdd/horas_extra.feature` | Especificación BDD (Gherkin) ejecutada por los tests |
| `docs/openapi.json` | Contrato OpenAPI generado |
| `backend/` | API REST Python/FastAPI (DDD en capas) |
| `desktop_client/` | Cliente Flutter Desktop Windows |

## Backend

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\pip install -r requirements.txt
.\.venv\Scripts\python -m pytest          # 25 pruebas: motor, BDD E2E, concurrencia
.\.venv\Scripts\uvicorn app.main:app --port 8000 --reload
```

- Swagger: <http://127.0.0.1:8000/docs>
- BD demo autogenerada (`backend/gestor_horas_extra.db`) con usuarios, festivos 2026 y quincena abierta.
- PostgreSQL producción: `GHE_DATABASE_URL=postgresql+psycopg://user:pass@host/db`

### Usuarios semilla (INKLUSIVA)

| Código | Clave | Rol | Persona |
|---|---|---|---|
| `LUISA` | `inklusiva` | Operativo | Colaborador 2 |
| `JOANNA` | `inklusiva` | Operativo | Colaborador 8 |
| `MARILUZ` | `inklusiva` | Operativo | Colaborador 3 |
| `YORLADIS` | `inklusiva` | Operativo | Colaborador 1 |
| `ADRIANA` | `inklusiva` | RH | Colaborador 7 |
| `JULIANA` | `inklusiva` | RH | Colaborador 5 |
| `ADMIN-1` | `admin123` | Admin | Sistemas |

### Motor de reglas

- Ventana diurna `[06:00, 21:00)`; nocturna el resto; domingo o fecha de tabla `festivos` ⇒ `DOMINICAL_FESTIVA`.
- Cruce de medianoche normalizado automáticamente; segmentación por fronteras de fecha y de ventana.
- Topes legales: 2 h/día y 12 h/semana. Modo `GHE_MODO_TOPES=BLOQUEO` rechaza con 409; modo ALERTA (default, canónico según BDD) registra con advertencia.
- Invariantes: sin solapamientos por colaborador, edición/cancelación bloqueadas en `APROBADA`/`CERRADA_EN_NOMINA`, fechas dentro de quincena cerrada devuelven `PERIODO_CONTABLE_CERRADO`.

## Cliente escritorio

```powershell
cd desktop_client
flutter pub get
flutter test                     # dominio espejo (7 pruebas)
flutter run -d windows           # usa API_URL=http://127.0.0.1:8000 por defecto
flutter build windows --release
```

Vistas por rol: **Operativa** (formulario con selector rápido de turno, cálculo local de tramos, historial con estados) y **RH** (filtros fecha/área/colaborador/estado, aprobación individual y masiva atómica, cierre de quincena y export CSV compatible Excel).

Si la red falla al enviar, la solicitud queda en una **cola local (outbox)** reintentable desde el botón flotante "N en cola".
