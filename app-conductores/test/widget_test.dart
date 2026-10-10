import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dart:typed_data';

import 'package:app_conductores/guantera/modelos.dart';
import 'package:app_conductores/ley/ley.dart';
import 'package:app_conductores/main.dart';
import 'package:app_conductores/ofertas/motor_ofertas.dart';
import 'package:app_conductores/ofertas/oferta.dart';

import 'apoyo/falsos.dart';

void main() {
  testWidgets('agregar un vehículo desde la pantalla de inicio', (tester) async {
    final dir = Directory.systemTemp.createTempSync('guantera_ui');
    addTearDown(() => dir.deleteSync(recursive: true));
    final (g, _, _) = (await tester
        .runAsync(() => guanteraDePrueba(dir, DateTime(2026, 10, 10))))!;

    await tester.pumpWidget(AppConductores(
        guantera: g, ofertas: MotorOfertas(ConfigOfertas.desactivada)));
    expect(find.text('Mis vehículos'), findsOneWidget);
    expect(find.textContaining('Agrega tu auto o moto'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Patente'), 'xx');
    await tester.tap(find.text('Guardar'));
    await tester.pump();
    expect(find.text('Patente no válida'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Patente'), 'abcd12');
    await tester.runAsync(() async {
      await tester.tap(find.text('Guardar'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(find.text('ABCD12'), findsOneWidget);
  });

  testWidgets('modo fiscalización muestra el resumen y no ofertas', (tester) async {
    final dir = Directory.systemTemp.createTempSync('guantera_fisc');
    addTearDown(() => dir.deleteSync(recursive: true));
    final (g, _, _) = (await tester
        .runAsync(() => guanteraDePrueba(dir, DateTime(2026, 10, 10))))!;
    await tester.runAsync(() async {
      final v = await g.guardarVehiculo(patente: 'ABCD12', tipo: TipoVehiculo.auto);
      await g.agregarDocumento(
          tipo: TipoDocumento.soap, vehiculoId: v.id, bytes: Uint8List(3),
          esPdf: true, nombreArchivo: 'x', vencimiento: DateTime(2026, 10, 1));
    });

    await tester.pumpWidget(AppConductores(
        guantera: g, ofertas: MotorOfertas(ConfigOfertas.desactivada)));
    await tester.tap(find.text('MODO FISCALIZACIÓN'));
    await tester.pumpAndSettle();

    expect(find.text('ABCD12'), findsOneWidget);
    expect(find.text('Resumen · 1/3'), findsOneWidget);
    expect(find.text('Vencido el 01-10-2026'), findsOneWidget);
    expect(find.text('No guardado en la app'), findsNWidgets(3));
    expect(find.textContaining('app de Conaset'), findsOneWidget);
  });

  testWidgets('pestaña Ley: buscar y abrir un artículo', (tester) async {
    final dir = Directory.systemTemp.createTempSync('guantera_ley');
    addTearDown(() => dir.deleteSync(recursive: true));
    final (g, _, _) = (await tester
        .runAsync(() => guanteraDePrueba(dir, DateTime(2026, 10, 10))))!;
    final ley = Ley.fromJson(jsonDecode(
        File('assets/ley/ley_18290.json').readAsStringSync()) as Map<String, dynamic>);

    await tester.pumpWidget(AppConductores(
        guantera: g, ofertas: MotorOfertas(ConfigOfertas.desactivada), ley: ley));
    await tester.tap(find.text('Ley'));
    await tester.pumpAndSettle();
    expect(find.text('Documentos obligatorios'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'art 51');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Artículo 51').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('seguro obligatorio', findRichText: true), findsWidgets);
  });
}
