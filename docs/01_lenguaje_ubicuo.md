# Lenguaje Ubicuo — Gestor de Horas Extra

Glosario canónico del dominio. Todos los artefactos (código, tests, UI, API) usan estos términos en español.

## Términos

| Término | Definición | Invariante/Regla asociada |
|---|---|---|
| **Colaborador / Operativo** | Persona que realiza y registra labor fuera de su jornada ordinaria. Identificado por código (ej. `OP-450`). | Solo ve y registra sus propias horas. |
| **Jornada Extraordinaria** | Intervalo de tiempo adicional trabajado fuera de la jornada ordinaria, clasificado por tipo de recargo. | Se descompone siempre en uno o más `TramoHorario`. |
| **TramoHorario** | Entidad hija del agregado `RegistroNovedad`. Intervalo contiguo homogéneo: hora inicio, hora fin y tipo calculado. | `minutos > 0`; fin posterior a inicio (admite cruce de medianoche). |
| **TipoRecargo** | Clasificación de cada tramo: `EXTRA_DIURNA`, `EXTRA_NOCTURNA`, `DOMINICAL_FESTIVA`. | Calculado por el Motor de Reglas; nunca ingresado a mano. |
| **Novedad / RegistroNovedad** | Entidad transaccional (raíz del agregado) que agrupa los tramos solicitados para una fecha específica, con justificación y estado. | Estado inicial `PENDIENTE_APROBACION`. |
| **EstadoNovedad** | Ciclo de vida: `PENDIENTE_APROBACION → APROBADA \| RECHAZADA`; `APROBADA → CERRADA_EN_NOMINA`. | No editable/eliminable en `APROBADA` ni `CERRADA_EN_NOMINA`. |
| **Corte de Nómina (Periodo)** | Ventana quincenal (ej. `2026-Q1-AGOSTO`) donde las horas aprobadas quedan congeladas para liquidación. | Al cerrar: novedades aprobadas pasan a `CERRADA_EN_NOMINA`; fechas dentro de periodo cerrado rechazan escrituras con `PERIODO_CONTABLE_CERRADO`. |
| **Aprobador / RH** | Rol responsable de auditar, aceptar (total) o rechazar novedades antes del cierre. Con observaciones obligatorias al rechazar. | Permisos de lectura global y cambio de estado. |
| **Motor de Reglas** | Servicio de dominio que divide un intervalo trabajado en tramos según ventanas diurna/nocturna y días domingos/festivos, y valida topes legales. | Determinista, puro, 100% cubierto por pruebas. |
| **Tope Legal** | Máximo permitido: por defecto **2 h diarias** y **12 h semanales** por colaborador. Configurable. | Exceder bloquea el registro (`TOPE_DIARIO_EXCEDIDO` / `TOPE_SEMANAL_EXCEDIDO`). |
| **Ventana Diurna** | Rango horario con recargo diurno: `[06:00, 21:00)` configurable. | Referencia para clasificar minutos. |
| **Ventana Nocturna** | Rango horario con recargo nocturno: `[21:00, 06:00)` del día siguiente, configurable. | Cruce de medianoche manejado explícitamente. |
| **Día Festivo** | Fecha del calendario (`tabla festivos`) que fuerza recargo `DOMINICAL_FESTIVA` para todos los minutos de esa fecha calendario. | Los minutos tras la medianoche cambian de fecha y por tanto de clasificación. |
| **Bandeja RH** | Vista de revisión con filtros (fecha, área, colaborador, estado) y acciones aprobar/rechazar/exportar. | Aprobaciones masivas atómicas (transacción única). |
| **Registro de Auditoría** | Tabla inmutable `audit_log` con: usuario, acción, timestamp, IP de origen, valores previos y nuevos. | Escritura-only; ninguna ruta la modifica o borra. |

## Reglas de oro

1. El tipo de recargo **siempre lo calcula el sistema**, jamás lo declara el usuario.
2. Un intervalo puede cruzar medianoche: se normaliza a `[inicio_dt, fin_dt)` y se segmenta.
3. Ninguna escritura toca periodos contables cerrados.
4. Toda mutación deja rastro de auditoría con valores previos/posteriores.
