# C4 — Nivel 2 (Contenedores)

```plantuml
C4Container
  title Diagrama de Contenedores - Sistema de Horas Extra

  Person(operaria, "Personal Operativo", "Registra horas extra trabajadas")
  Person(rh, "Personal de RH", "Revisa, aprueba y exporta a nómina")

  System_Boundary(c1, "Plataforma de Horas Extra") {
    Container(desktop_app, "App de Escritorio", "Flutter Desktop / Dart", "Interfaz gráfica para registro y panel RH. Outbox offline ligero.")
    Container(api_backend, "API Backend", "Python FastAPI", "Valida reglas de negocio, calcula recargos y gestiona estados")
    ContainerDb(db, "Base de Datos", "SQLite (dev) / PostgreSQL (prod)", "Almacena usuarios, novedades, tramos, periodos y auditoría")
  }

  System_Ext(payroll_system, "Software de Nómina", "Recibe el consolidado quincenal para dispersión de pagos")

  Rel(operaria, desktop_app, "Registra novedades en", "GUI")
  Rel(rh, desktop_app, "Audita y aprueba en", "GUI")
  Rel(desktop_app, api_backend, "Envía solicitudes y consultas vía", "HTTPS / JSON + JWT")
  Rel(api_backend, db, "Lee y escribe datos en", "SQLAlchemy ORM")
  Rel(api_backend, payroll_system, "Exporta novedades liquidadas vía", "CSV")
```

## Nivel 3 — Componentes del API Backend

| Componente | Responsabilidad |
|---|---|
| `dominio/motor_reglas` | Segmentación diurna/nocturna/festiva + topes legales (puro, sin I/O). |
| `dominio/entidades` | Agregado `RegistroNovedad` + invariantes de estado. |
| `api/rutas/auth` | Login, emisión JWT, refresco de identidad. |
| `api/rutas/horas_extra` | Solicitar, previsualizar tramos, historial propio, cancelar. |
| `api/rutas/rh` | Bandeja con filtros, aprobar/rechazar, periodos, export CSV. |
| `infra/repositorios` | Persistencia transaccional + detección de solapamientos. |
| `core/auditoria` | Escritura inmutable de `audit_log`. |

## Cliente Flutter — Estructura

```
lib/
├── core/            # http cliente autenticado, outbox, tema
├── domain/          # espejo del motor de reglas para vista previa
├── data/            # DTOs y repositorios remotos
└── presentation/    # login, shell por rol, operativo, rh
```
