import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:app_conductores/guantera/fiscalizacion.dart';
import 'package:app_conductores/guantera/modelos.dart';

import '../apoyo/falsos.dart';

void main() {
  late Directory dir;
  final bytes = Uint8List.fromList([1, 2, 3]);
  setUp(() => dir = Directory.systemTemp.createTempSync('fisc'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('obligatorios siempre listados, complementarios solo si existen', () async {
    final (g, _, _) = await guanteraDePrueba(dir, DateTime(2026, 10, 10));
    final v = await g.guardarVehiculo(patente: 'ABCD12', tipo: TipoVehiculo.auto);
    final otro = await g.guardarVehiculo(patente: 'BBB12', tipo: TipoVehiculo.moto);
    Future<Documento> agregar(TipoDocumento t, String? vid, [DateTime? f]) =>
        g.agregarDocumento(
            tipo: t, vehiculoId: vid, bytes: bytes, esPdf: true,
            nombreArchivo: 'x', vencimiento: f);

    final soap = await agregar(TipoDocumento.soap, v.id, DateTime(2027, 3, 31));
    await agregar(TipoDocumento.soap, otro.id, DateTime(2027, 3, 31));
    final lic = await agregar(TipoDocumento.licencia, null, DateTime(2030));
    await agregar(TipoDocumento.cedula, null, DateTime(2031));

    final items = itemsFiscalizacion(g, v.id);
    expect(items.map((i) => i.tipo), [...obligatorios, TipoDocumento.cedula]);
    expect(items.firstWhere((i) => i.tipo == TipoDocumento.soap).documento!.id, soap.id);
    expect(items.first.documento!.id, lic.id);
    expect(items.firstWhere((i) => i.tipo == TipoDocumento.padron).documento, isNull);
  });

  test('entre duplicados elige el de vencimiento más lejano', () async {
    final (g, _, _) = await guanteraDePrueba(dir, DateTime(2026, 10, 10));
    final v = await g.guardarVehiculo(patente: 'ABCD12', tipo: TipoVehiculo.auto);
    await g.agregarDocumento(tipo: TipoDocumento.revisionTecnica, vehiculoId: v.id,
        bytes: bytes, esPdf: true, nombreArchivo: 'vieja', vencimiento: DateTime(2026, 5, 1));
    final nueva = await g.agregarDocumento(tipo: TipoDocumento.revisionTecnica, vehiculoId: v.id,
        bytes: bytes, esPdf: true, nombreArchivo: 'nueva', vencimiento: DateTime(2027, 5, 1));
    final rt = itemsFiscalizacion(g, v.id)
        .firstWhere((i) => i.tipo == TipoDocumento.revisionTecnica);
    expect(rt.documento!.id, nueva.id);
  });

  test('sin vehículo muestra solo documentos personales', () async {
    final (g, _, _) = await guanteraDePrueba(dir, DateTime(2026, 10, 10));
    final items = itemsFiscalizacion(g, null);
    expect(items.every((i) => i.documento == null), isTrue);
  });
}
