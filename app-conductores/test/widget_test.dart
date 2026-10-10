import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
