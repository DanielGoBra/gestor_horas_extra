import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_horas_extra_client/domain/motor_reglas.dart';

DateTime f(int y, int m, int d) => DateTime(y, m, d);

List<(String, String)> rangos(List<TramoCalculado> tramos) => tramos
    .map((t) => (
        '${t.inicio.hour.toString().padLeft(2, '0')}:${t.inicio.minute.toString().padLeft(2, '0')}',
        '${t.fin.hour.toString().padLeft(2, '0')}:${t.fin.minute.toString().padLeft(2, '0')}'))
    .toList();

void main() {
  group('Escenario BDD: cruce diurno -> nocturno', () {
    test('18:00 a 23:00 divide en diurna 3h y nocturna 2h', () {
      final tramos = calcularTramos(f(2026, 8, 10), 18, 0, 23, 0);
      expect(tramos.map((t) => t.tipoHora).toList(),
          [TipoHora.extraDiurna, TipoHora.extraNocturna]);
      expect(rangos(tramos), [('18:00', '21:00'), ('21:00', '23:00')]);
      expect(totalMinutos(tramos), 300);
    });
  });

  group('Cruce de medianoche', () {
    test('23:00 a 01:00 es un solo tramo nocturno fusionado', () {
      final tramos = calcularTramos(f(2026, 8, 17), 23, 0, 1, 0);
      expect(tramos, hasLength(1));
      expect(tramos.first.tipoHora, TipoHora.extraNocturna);
      expect(totalMinutos(tramos), 120);
    });

    test('domingo hacia lunes segmenta por fecha calendario', () {
      final tramos = calcularTramos(f(2026, 8, 16), 22, 0, 2, 0);
      expect(tramos.map((t) => t.tipoHora).toList(),
          [TipoHora.dominicalFestiva, TipoHora.extraNocturna]);
      expect(rangos(tramos), [('22:00', '00:00'), ('00:00', '02:00')]);
    });

    test('24 horas exactas lanza IntervaloInvalido', () {
      expect(() => calcularTramos(f(2026, 8, 16), 1, 0, 1, 0),
          throwsA(isA<IntervaloInvalido>()));
    });
  });

  group('Dominical/festiva', () {
    test('domingo completo es dominical festiva', () {
      final tramos = calcularTramos(f(2026, 8, 16), 10, 0, 13, 0);
      expect(tramos.single.tipoHora, TipoHora.dominicalFestiva);
    });

    test('tabla de festivos aplica entre semana', () {
      final festivos = {f(2026, 8, 7)};
      final tramos =
          calcularTramos(f(2026, 8, 7), 9, 0, 11, 0, festivos: festivos);
      expect(tramos.single.tipoHora, TipoHora.dominicalFestiva);
    });
  });

  test('minutosPorFecha reparte por medianoche para topes', () {
    final tramos = calcularTramos(f(2026, 8, 16), 23, 0, 1, 0);
    final reparto = minutosPorFecha(tramos);
    expect(reparto[f(2026, 8, 16)], 60);
    expect(reparto[f(2026, 8, 17)], 60);
  });
}
