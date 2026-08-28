# ADR-001 — Arquitectura Cliente de Escritorio con Backend API REST Centralizado

- **Estado:** Aceptado (2026-08-25)
- **Contexto:** Las estaciones de trabajo operativas y de RH requieren una app de escritorio nativa para acceso ágil en planta y oficina. No es viable que el cliente acceda directamente a la base de datos por seguridad y control de versiones.
- **Decisión:**
  - **Cliente Desktop:** Flutter Desktop (Windows). Distribución sencilla, rendimiento nativo, tipado fuerte y pruebas automatizadas.
  - **Backend Core:** API REST con Python 3.14 + FastAPI. Responsable exclusivo de reglas de negocio, cálculo de recargos y transiciones de estado.
  - **Base de Datos:** Esquema relacional definido sobre SQLAlchemy 2.x ORM. Desarrollo local en SQLite; producción en PostgreSQL sin cambios de dominio (mismos modelos, migraciones Alembic-ready).
  - **Auth:** JWT firmado (PyJWT), roles `OPERATIVO`, `SUPERVISOR`, `RH`, `ADMIN`. Hash de contraseñas PBKDF2-HMAC-SHA256.
- **Consecuencias:**
  - Se requiere conexión a red local/VPN corporativa para sincronizar.
  - El cliente implementa una **cola local ligera (outbox)** que retiene solicitudes si la red presenta intermitencia temporal y las reintenta manual/automáticamente.
  - El motor de reglas se duplica como *vista previa* en cliente (UX) pero la **única fuente de verdad es el backend**.

## ADR-002 — Clasificación de tramos por segmentación de minutos

- **Estado:** Aceptado
- **Decisión:** El intervalo `[hora_inicio, hora_fin)` se normaliza a datetimes (si `fin <= inicio` cruza medianoche → fin +1 día). Se generan puntos de corte en cada frontera relevante (medianoche por cambio de fecha/festivos, 06:00 y 21:00 por cambio diurna/nocturna) y se clasifica cada segmento por su punto medio. Segmentos contiguos homogéneos se fusionan.
- **Alternativa descartada:** restas aritméticas por rangos fijos; falla con festivos parciales tras medianoche.

## ADR-003 — Auditoría inmutable vía servicio de aplicación

- **Estado:** Aceptado
- **Decisión:** Toda mutación pasa por un servicio que escribe en `audit_log` dentro de la misma transacción (usuario_id, acción, timestamp UTC, IP origen, snapshot previo/nuevo en JSON). La tabla no expone rutas de modificación/borrado.
