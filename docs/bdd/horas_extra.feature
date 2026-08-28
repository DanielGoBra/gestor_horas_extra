# language: es
Característica: Registro de Horas Extraordinarias con cruce de medianoche
  Como personal operativo quiero registrar mis horas extra
  para que RH las audite y liquide correctamente según tipo de recargo.

  Antecedentes:
    Dado un horario nocturno que inicia a las "21:00"
    Y el colaborador "OP-450" finaliza su jornada ordinaria a las "18:00"

  Escenario: Operativo registra turno que cruza de horario diurno a nocturno
    Cuando registra horas extra desde las "18:00" hasta las "23:00" del mismo día
    Entonces el sistema debe dividir el registro en dos tramos automáticos:
      | Tipo           | Inicio | Fin   | Total Horas |
      | Extra Diurna   | 18:00  | 21:00 | 3           |
      | Extra Nocturna | 21:00  | 23:00 | 2           |
    Y el estado inicial de la novedad debe ser "PENDIENTE_APROBACION"

  Escenario: Turno nocturno que cruza la medianoche se segmenta por fecha calendario
    Cuando registra horas extra desde las "22:00" hasta las "02:00" del día siguiente
    Entonces el sistema debe normalizar el intervalo al día siguiente y producir tramos:
      | Tipo           | Inicio | Fin   |
      | Extra Nocturna | 22:00  | 00:00 |
      | Extra Nocturna | 00:00  | 02:00 |

  Escenario: Domingo produce recargo dominical/festivo en todo el día
    Dado que el "2026-08-16" es domingo
    Cuando registra horas extra desde las "10:00" hasta las "13:00" de ese día
    Entonces el sistema debe clasificar el tramo completo como "DOMINICAL_FESTIVA"

  Escenario: Tramos solapados para el mismo colaborador son rechazados
    Dado una novedad "PENDIENTE_APROBACION" de "OP-450" el "2026-08-10" de "18:00" a "20:00"
    Cuando intenta registrar "19:00" a "21:00" del mismo día
    Entonces el sistema rechaza la operación con el error "TRAMOS_SOLAPADOS"

  Escenario: Hora final anterior a la hora inicial cruza medianoche automáticamente
    Cuando registra horas extra desde las "23:00" hasta las "01:00"
    Entonces el sistema lo interpreta como cruce de medianoche
    Y valida los topes legales sobre el total resultante

  Escenario: Bloqueo por tope diario legal
    Dado un tope legal de "2" horas diarias
    Cuando registra horas extra desde las "18:00" hasta las "21:30"
    Entonces el sistema rechaza la operación con el error "TOPE_DIARIO_EXCEDIDO"

# language: es
Característica: Aprobación, Corte de Nómina e Immutabilidad

  Escenario: RH aprueba novedad pendiente
    Dado una novedad "PENDIENTE_APROBACION" de "OP-450"
    Cuando el aprobador RH la aprueba con observación ""
    Entonces su estado pasa a "APROBADA"
    Y queda registrado en auditoría con valores previos y nuevos

  Escenario: Rechazo exige observación
    Cuando el aprobador RH rechaza sin observaciones
    Entonces el sistema responde con el error "OBSERVACION_REQUERIDA"

  Escenario: Intento de modificación sobre periodo cerrado
    Dado que la quincena "2026-Q1-AGOSTO" se encuentra en estado "CERRADO"
    Cuando el usuario intenta editar una novedad del día "2026-08-10"
    Entonces el sistema debe rechazar la operación con el error "PERIODO_CONTABLE_CERRADO"

  Escenario: Cierre de quincena congela novedades aprobadas
    Dado novedades "APROBADA" dentro de la quincena "2026-Q2-AGOSTO"
    Cuando RH cierra el periodo "2026-Q2-AGOSTO"
    Entonces todas pasan a estado "CERRADA_EN_NOMINA"
    Y el consolidado queda disponible para exportar a CSV

  Escenario: Operativo no puede consultar horas de otros colaboradores
    Dado el usuario autenticado "OP-450" con rol "OPERATIVO"
    Cuando consulta la bandeja de RH
    Entonces el sistema responde "403 PERMISO_DENEGADO"
