# Esquema de Datos Relacional

Compatible SQLite (dev) ↔ PostgreSQL (prod) vía SQLAlchemy 2.x.

```sql
-- IAM
usuarios (
  id INTEGER PK,
  codigo TEXT UNIQUE NOT NULL,          -- 'OP-450'
  nombre TEXT NOT NULL,
  area TEXT NOT NULL,                   -- 'Produccion', 'Calidad'...
  rol TEXT CHECK (rol IN ('OPERATIVO','SUPERVISOR','RH','ADMIN')),
  password_hash TEXT NOT NULL,          -- pbkdf2_sha256$iter$salt$hash
  activo BOOLEAN DEFAULT TRUE
)

-- Calendario
festivos ( fecha DATE PK )

-- Agregado Novedad
solicitudes_horas_extra (
  id INTEGER PK,
  colaborador_id INTEGER FK->usuarios NOT NULL,
  fecha_trabajo DATE NOT NULL,          -- fecha calendario de inicio
  justificacion TEXT NOT NULL,
  estado TEXT CHECK (estado IN ('PENDIENTE_APROBACION','APROBADA','RECHAZADA','CERRADA_EN_NOMINA')),
  observacion_rh TEXT,
  aprobada_por INTEGER FK->usuarios,
  creada_en TIMESTAMP NOT NULL,
  actualizada_en TIMESTAMP NOT NULL
)

tramos_detalle (
  id INTEGER PK,
  solicitud_id INTEGER FK->solicitudes_horas_extra ON DELETE CASCADE,
  inicio_datetime TIMESTAMP NOT NULL,
  fin_datetime TIMESTAMP NOT NULL,
  tipo_hora TEXT CHECK (tipo_hora IN ('EXTRA_DIURNA','EXTRA_NOCTURNA','DOMINICAL_FESTIVA')),
  minutos INTEGER CHECK (minutos > 0)
)

-- Corte de Nómina
cortes_nomina (
  id INTEGER PK,
  etiqueta TEXT UNIQUE NOT NULL,        -- '2026-Q1-AGOSTO'
  fecha_inicio DATE NOT NULL,
  fecha_fin   DATE NOT NULL,
  estado TEXT CHECK (estado IN ('ABIERTO','CERRADO')) DEFAULT 'ABIERTO',
  cerrado_en TIMESTAMP,
  cerrado_por INTEGER FK->usuarios
)

-- Auditoría inmutable
audit_log (
  id INTEGER PK,
  usuario_id INTEGER FK->usuarios,
  accion TEXT NOT NULL,                 -- LOGIN, CREAR_NOVEDAD, APROBAR...
  timestamp_utc TIMESTAMP NOT NULL,
  ip_origen TEXT,
  valores_previos JSON,
  valores_nuevos JSON
)
```

### Parámetros del Motor de Reglas (config)

| Parámetro | Default | Descripción |
|---|---|---|
| `INICIO_DIURNA` / `FIN_DIURNA` | 06:00 / 21:00 | Ventana diurna `[06:00, 21:00)` |
| `TOPE_HORAS_DIARIAS` | 2 | Bloqueo si total del día lo excede |
| `TOPE_HORAS_SEMANALES` | 12 | Semana ISO (lunes–domingo), bloqueo al exceder |

### Índices y consistencia

- Índice único funcional equivalente: detección de solapamiento por consulta transaccional (`fecha + rangos` con estado distinto a `RECHAZADA`) — portable entre SQLite/PG.
- Aprobaciones masivas: una sola transacción (`BEGIN ... COMMIT`) → atomicidad ACID.
- `CERRADA_EN_NOMINA` se aplica en cascada al cerrar el periodo dentro de la misma transacción.
