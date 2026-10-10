import 'package:flutter_test/flutter_test.dart';

import 'package:app_conductores/guantera/modelos.dart';

Documento _doc(DateTime? vence) => Documento(
      id: 'd1',
      tipo: TipoDocumento.soap,
      archivoId: 'a1',
      esPdf: true,
      nombreArchivo: 'soap.pdf',
      creado: DateTime(2026),
      vencimiento: vence,
    );

void main() {
  final hoy = DateTime(2026, 10, 10);

  test('estado según días para vencer', () {
    expect(estadoDe(_doc(null), hoy), EstadoVencimiento.sinVencimiento);
    expect(estadoDe(_doc(DateTime(2026, 10, 9)), hoy), EstadoVencimiento.vencido);
    expect(estadoDe(_doc(DateTime(2026, 10, 10)), hoy), EstadoVencimiento.porVencer);
    expect(estadoDe(_doc(DateTime(2026, 11, 9)), hoy), EstadoVencimiento.porVencer);
    expect(estadoDe(_doc(DateTime(2026, 11, 10)), hoy), EstadoVencimiento.vigente);
  });

  test('días para vencer no se altera con cambio de horario', () {
    // Chile cambia de horario en septiembre y abril.
    expect(diasParaVencer(_doc(DateTime(2026, 9, 10)), DateTime(2026, 8, 31)), 10);
  });

  test('sugerencia 31 de marzo para permiso y SOAP', () {
    expect(vencimientoSugerido(TipoDocumento.soap, hoy), DateTime(2027, 3, 31));
    expect(vencimientoSugerido(TipoDocumento.permisoCirculacion, DateTime(2026, 2, 1)),
        DateTime(2026, 3, 31));
    expect(vencimientoSugerido(TipoDocumento.soap, DateTime(2026, 3, 31)),
        DateTime(2026, 3, 31));
    expect(vencimientoSugerido(TipoDocumento.revisionTecnica, hoy), isNull);
  });

  test('patentes', () {
    expect(normalizarPatente(' ab-cd·12 '), 'ABCD12');
    for (final p in ['ABCD12', 'AB1234', 'BBB12', 'AB123']) {
      expect(patenteValida(p), isTrue, reason: p);
    }
    for (final p in ['ABC', '123456', 'ABCDE1', 'AB12345', '12ABCD']) {
      expect(patenteValida(p), isFalse, reason: p);
    }
  });

  test('JSON ida y vuelta', () {
    final d = _doc(DateTime(2027, 3, 31));
    final r = Documento.fromJson(d.toJson());
    expect(r.vencimiento, d.vencimiento);
    expect(r.tipo, TipoDocumento.soap);
    const v = Vehiculo(id: 'v', patente: 'ABCD12', tipo: TipoVehiculo.moto, anio: 2020);
    expect(Vehiculo.fromJson(v.toJson()).tipo, TipoVehiculo.moto);
  });

  test('solo licencia y cédula son personales', () {
    expect(TipoDocumento.values.where((t) => t.personal),
        [TipoDocumento.licencia, TipoDocumento.cedula]);
  });
}
