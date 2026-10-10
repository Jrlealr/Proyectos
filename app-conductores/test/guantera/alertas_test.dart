import 'package:flutter_test/flutter_test.dart';

import 'package:app_conductores/guantera/alertas.dart';
import 'package:app_conductores/guantera/modelos.dart';

Documento _doc(String id, DateTime? vence) => Documento(
      id: id,
      tipo: TipoDocumento.revisionTecnica,
      archivoId: 'a',
      esPdf: true,
      nombreArchivo: 'rt.pdf',
      creado: DateTime(2026),
      vencimiento: vence,
    );

void main() {
  test('programa avisos a 30, 15, 1 y 0 días a las 9:00', () {
    final a = planificarAlertas(
        _doc('x', DateTime(2026, 12, 31)), 'ABCD12', DateTime(2026, 10, 10));
    expect(a.map((e) => e.fecha), [
      DateTime(2026, 12, 1, 9),
      DateTime(2026, 12, 16, 9),
      DateTime(2026, 12, 30, 9),
      DateTime(2026, 12, 31, 9),
    ]);
    expect(a.first.cuerpo, 'Tu revisión técnica de ABCD12 vence en 30 días.');
    expect(a.last.cuerpo, contains('vence hoy'));
  });

  test('omite avisos pasados y documentos sin fecha', () {
    final a = planificarAlertas(
        _doc('x', DateTime(2026, 10, 20)), null, DateTime(2026, 10, 10, 12));
    expect(a.map((e) => e.fecha),
        [DateTime(2026, 10, 19, 9), DateTime(2026, 10, 20, 9)]);
    expect(planificarAlertas(_doc('x', null), null, DateTime(2026)), isEmpty);
  });

  test('ids de notificación estables, distintos y positivos', () {
    final ids = {
      for (final d in ['a', 'b', 'c0ffee'])
        for (var i = 0; i < diasDeAviso.length; i++) idNotificacion(d, i)
    };
    expect(ids.length, 12);
    expect(ids.every((i) => i > 0 && i < 0x80000000), isTrue);
    expect(idNotificacion('a', 2), idNotificacion('a', 2));
  });
}
