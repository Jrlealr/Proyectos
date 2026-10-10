import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:app_conductores/guantera/almacen.dart';
import 'package:app_conductores/guantera/cifrado.dart';
import 'package:app_conductores/guantera/modelos.dart';

import '../apoyo/falsos.dart';

void main() {
  late Directory dir;
  final hoy = DateTime(2026, 10, 10);
  final pdf = Uint8List.fromList('%PDF-1.4 permiso circulacion ABCD12'.codeUnits);

  setUp(() => dir = Directory.systemTemp.createTempSync('guantera'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('guarda, cifra y recarga vehículos y documentos', () async {
    final (g, alertas, _) = await guanteraDePrueba(dir, hoy);
    final v = await g.guardarVehiculo(patente: 'ab-cd 12', tipo: TipoVehiculo.auto);
    expect(v.patente, 'ABCD12');
    final d = await g.agregarDocumento(
      tipo: TipoDocumento.permisoCirculacion,
      vehiculoId: v.id,
      bytes: pdf,
      esPdf: true,
      nombreArchivo: 'permiso.pdf',
      vencimiento: DateTime(2027, 3, 31, 15, 30),
    );
    expect(d.vencimiento, DateTime(2027, 3, 31));
    expect(alertas.programadas[d.id], 'ABCD12');

    // Nada en claro en disco.
    for (final f in dir.listSync(recursive: true).whereType<File>()) {
      final contenido = String.fromCharCodes(f.readAsBytesSync());
      expect(contenido.contains('ABCD12'), isFalse, reason: f.path);
      expect(contenido.contains('%PDF'), isFalse, reason: f.path);
    }

    final (g2, _, _) = await guanteraDePrueba(dir, hoy);
    expect(g2.vehiculos.single.patente, 'ABCD12');
    final d2 = g2.documentosDe(v.id).single;
    expect(await g2.leerArchivo(d2), pdf);
  });

  test('con otra clave no se puede leer y no se pierde el archivo', () async {
    final (g, _, _) = await guanteraDePrueba(dir, hoy);
    await g.guardarVehiculo(patente: 'ABCD12', tipo: TipoVehiculo.auto);
    final ajeno = AlmacenGuantera(dir, Cifrador(ClaveFija(9)));
    final datos = await ajeno.cargar();
    expect(datos.vehiculos, isEmpty);
    // El índice ilegible se conserva aparte, no se sobrescribe.
    expect(dir.listSync().map((f) => f.path).any((p) => p.contains('.ilegible-')),
        isTrue);
  });

  test('documentos personales no quedan asociados a un vehículo', () async {
    final (g, _, _) = await guanteraDePrueba(dir, hoy);
    final v = await g.guardarVehiculo(patente: 'ABCD12', tipo: TipoVehiculo.auto);
    final lic = await g.agregarDocumento(
      tipo: TipoDocumento.licencia,
      vehiculoId: v.id,
      bytes: pdf,
      esPdf: false,
      nombreArchivo: 'lic.jpg',
    );
    expect(lic.vehiculoId, isNull);
    expect(g.documentosDe(null).single.id, lic.id);
    expect(g.documentosDe(v.id), isEmpty);
  });

  test('vencimientos ordenados y estado del vehículo', () async {
    final (g, _, _) = await guanteraDePrueba(dir, hoy);
    final v = await g.guardarVehiculo(patente: 'BBB12', tipo: TipoVehiculo.moto);
    Future<Documento> agregar(TipoDocumento t, DateTime? f) => g.agregarDocumento(
        tipo: t, vehiculoId: v.id, bytes: pdf, esPdf: true, nombreArchivo: 'x', vencimiento: f);
    await agregar(TipoDocumento.padron, null);
    await agregar(TipoDocumento.soap, DateTime(2027, 3, 31));
    expect(g.estadoVehiculo(v.id), EstadoVencimiento.vigente);
    await agregar(TipoDocumento.revisionTecnica, DateTime(2026, 10, 20));
    expect(g.estadoVehiculo(v.id), EstadoVencimiento.porVencer);
    expect(g.vencimientos.map((d) => d.tipo),
        [TipoDocumento.revisionTecnica, TipoDocumento.soap]);
  });

  test('actualizar vencimiento reprograma alertas', () async {
    final (g, alertas, _) = await guanteraDePrueba(dir, hoy);
    final d = await g.agregarDocumento(
        tipo: TipoDocumento.licencia, bytes: pdf, esPdf: true, nombreArchivo: 'x',
        vencimiento: DateTime(2026, 10, 1));
    expect(estadoDe(d, g.hoy), EstadoVencimiento.vencido);
    await g.actualizarVencimiento(d, DateTime(2032, 10, 1));
    expect(estadoDe(g.documentosDe(null).single, g.hoy), EstadoVencimiento.vigente);
    expect(alertas.programadas.containsKey(d.id), isTrue);
  });

  test('borrar vehículo borra sus documentos, archivos y alertas', () async {
    final (g, alertas, almacen) = await guanteraDePrueba(dir, hoy);
    final v = await g.guardarVehiculo(patente: 'ABCD12', tipo: TipoVehiculo.auto);
    final d = await g.agregarDocumento(
        tipo: TipoDocumento.soap, vehiculoId: v.id, bytes: pdf, esPdf: true,
        nombreArchivo: 'x', vencimiento: DateTime(2027, 3, 31));
    await g.borrarVehiculo(v.id);
    expect(g.vehiculos, isEmpty);
    expect(g.vencimientos, isEmpty);
    expect(alertas.canceladas, contains(d.id));
    expect(almacen.leerArchivo(d.archivoId), throwsA(anything));
  });

  test('ajuste de ofertas y descartes persisten', () async {
    final (g, _, _) = await guanteraDePrueba(dir, hoy);
    expect(g.permiteOfertas, isTrue);
    await g.cambiarPermiteOfertas(false);
    await g.descartarOferta('soap_compra@d1:2027');
    final (g2, _, _) = await guanteraDePrueba(dir, hoy);
    expect(g2.permiteOfertas, isFalse);
    expect(g2.ofertasDescartadas, {'soap_compra@d1:2027'});
  });
}
