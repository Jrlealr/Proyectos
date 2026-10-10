import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:app_conductores/guantera/alertas.dart';
import 'package:app_conductores/guantera/control.dart';
import 'package:app_conductores/guantera/modelos.dart';

import '../apoyo/falsos.dart';

Control _control({DateTime? comparecencia, List<Adjunto> adjuntos = const []}) => Control(
      id: 'c1',
      fechaHora: DateTime(2026, 10, 10, 14, 5),
      patente: 'ABCD12',
      lugar: 'Av. Providencia con Los Leones',
      latitud: -33.4234567,
      longitud: -70.6098761,
      funcionarioGrado: 'Cabo',
      funcionarioNombre: 'Pérez',
      motivo: 'Control de documentos',
      resultado: ResultadoControl.citacion,
      numeroCitacion: '12345',
      juzgado: '1° JPL de Providencia',
      fechaComparecencia: comparecencia,
      infracciones: 'No portar SOAP',
      adjuntos: adjuntos,
    );

void main() {
  test('JSON ida y vuelta', () {
    final c = _control(
        comparecencia: DateTime(2026, 10, 20, 9, 30),
        adjuntos: const [Adjunto(archivoId: 'a', esPdf: false, nombre: 'cita.jpg')]);
    final r = Control.fromJson(c.toJson());
    expect(r.toJson(), c.toJson());
  });

  test('resumen para descargos', () {
    final t = resumenControl(_control(comparecencia: DateTime(2026, 10, 20, 9, 30)));
    expect(t, contains('Fecha y hora: 10-10-2026 14:05'));
    expect(t, contains('Vehículo (patente): ABCD12'));
    expect(t, contains('Coordenadas: -33.423457, -70.609876'));
    expect(t, contains('Funcionario: Cabo Pérez'));
    expect(t, contains('Institución: Carabineros de Chile'));
    expect(t, contains('Comparecencia: 20-10-2026 09:30'));
    expect(t, isNot(contains('Notas:')));
  });

  test('avisos de comparecencia: día anterior 9:00 y 2 horas antes', () {
    final a = planificarComparecencia(
        _control(comparecencia: DateTime(2026, 10, 20, 9, 30)), DateTime(2026, 10, 10));
    expect(a.map((e) => e.fecha), [DateTime(2026, 10, 19, 9), DateTime(2026, 10, 20, 7, 30)]);
    expect(a.first.cuerpo, 'Mañana debes presentarte en 1° JPL de Providencia.');
    expect(planificarComparecencia(_control(), DateTime(2026)), isEmpty);
    expect(
        planificarComparecencia(
            _control(comparecencia: DateTime(2026, 10, 20, 9, 30)), DateTime(2026, 10, 20, 8)),
        isEmpty);
  });

  group('guantera', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('controles'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('guarda con adjuntos cifrados, edita y borra', () async {
      final (g, alertas, almacen) = await guanteraDePrueba(dir, DateTime(2026, 10, 10));
      final foto = Uint8List.fromList('FOTO-CITACION-12345'.codeUnits);
      final c = await g.guardarControl(
          _control(comparecencia: DateTime(2026, 10, 20, 9, 30)),
          nuevosAdjuntos: [(foto, false, 'cita.jpg')]);
      expect(c.adjuntos.single.nombre, 'cita.jpg');
      expect(await g.leerAdjunto(c.adjuntos.single), foto);
      expect(alertas.controles, {'c1'});

      for (final f in dir.listSync(recursive: true).whereType<File>()) {
        final s = String.fromCharCodes(f.readAsBytesSync());
        expect(s.contains('12345') || s.contains('Providencia'), isFalse, reason: f.path);
      }

      // Recarga desde disco.
      final (g2, _, _) = await guanteraDePrueba(dir, DateTime(2026, 10, 10));
      expect(g2.controles.single.juzgado, '1° JPL de Providencia');

      // Editar quitando el adjunto lo borra del disco.
      final archivo = c.adjuntos.single;
      await g.guardarControl(c.copyWith(adjuntos: []));
      expect(g.control('c1')!.adjuntos, isEmpty);
      expect(almacen.leerArchivo(archivo.archivoId), throwsA(anything));

      await g.borrarControl(g.control('c1')!);
      expect(g.controles, isEmpty);
      expect(alertas.controles, isEmpty);
    });

    test('el control conserva la patente si se borra el vehículo', () async {
      final (g, _, _) = await guanteraDePrueba(dir, DateTime(2026, 10, 10));
      final v = await g.guardarVehiculo(patente: 'BBB12', tipo: TipoVehiculo.moto);
      await g.guardarControl(Control(
          id: 'x', fechaHora: DateTime(2026, 10, 1), vehiculoId: v.id, patente: v.patente));
      await g.borrarVehiculo(v.id);
      expect(g.controles.single.patente, 'BBB12');
    });

    test('orden: más reciente primero', () async {
      final (g, _, _) = await guanteraDePrueba(dir, DateTime(2026, 10, 10));
      await g.guardarControl(Control(id: 'a', fechaHora: DateTime(2026, 1, 1)));
      await g.guardarControl(Control(id: 'b', fechaHora: DateTime(2026, 5, 1)));
      expect(g.controles.map((c) => c.id), ['b', 'a']);
    });
  });
}
