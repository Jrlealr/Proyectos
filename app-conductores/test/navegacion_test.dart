import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:app_conductores/navegacion/navegacion.dart';

import 'apoyo/falsos.dart';

void main() {
  test('Google Maps: búsqueda y coordenadas', () {
    expect(
      uriNavegacion(AppNavegacion.googleMaps, const DestinoBusqueda('Juzgado de Policía Local')).toString(),
      'https://www.google.com/maps/search/?api=1&query=Juzgado+de+Polic%C3%ADa+Local',
    );
    expect(
      uriNavegacion(AppNavegacion.googleMaps, const DestinoCoordenadas(-33.45, -70.66)).toString(),
      'https://www.google.com/maps/dir/?api=1&destination=-33.45%2C-70.66&travelmode=driving',
    );
  });

  test('Waze: búsqueda y coordenadas', () {
    expect(
      uriNavegacion(AppNavegacion.waze, const DestinoBusqueda('planta de revisión técnica')).toString(),
      'https://waze.com/ul?q=planta+de+revisi%C3%B3n+t%C3%A9cnica&navigate=yes',
    );
    expect(
      uriNavegacion(AppNavegacion.waze, const DestinoCoordenadas(-33.45, -70.66)).toString(),
      'https://waze.com/ul?ll=-33.45%2C-70.66&navigate=yes',
    );
  });

  test('destino del juzgado según lo escrito por el usuario', () {
    String texto(Destino d) => (d as DestinoBusqueda).texto;
    expect(texto(LugaresUtiles.juzgado('')), 'Juzgado de Policía Local');
    expect(texto(LugaresUtiles.juzgado('1° JPL de Providencia')), '1° JPL de Providencia');
    expect(texto(LugaresUtiles.juzgado('Maipú')), 'Juzgado de Policía Local Maipú');
  });

  test('la preferencia de app se guarda', () async {
    final dir = Directory.systemTemp.createTempSync('nav');
    addTearDown(() => dir.deleteSync(recursive: true));
    final (g, _, _) = await guanteraDePrueba(dir, DateTime(2026, 10, 10));
    expect(g.appNavegacion, AppNavegacion.preguntar);
    await g.cambiarAppNavegacion(AppNavegacion.waze);
    final (g2, _, _) = await guanteraDePrueba(dir, DateTime(2026, 10, 10));
    expect(g2.appNavegacion, AppNavegacion.waze);
  });
}
