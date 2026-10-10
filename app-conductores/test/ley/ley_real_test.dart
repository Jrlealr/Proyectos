import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:app_conductores/ley/ley.dart';

/// Verifica el texto empaquetado (generado por tool/ley/convertir.py).
void main() {
  final ley = Ley.fromJson(jsonDecode(
          File('assets/ley/ley_18290.json').readAsStringSync())
      as Map<String, dynamic>);

  test('texto completo y con fecha de versión', () {
    expect(ley.articulos.length, greaterThan(200));
    expect(ley.versionFecha, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
  });

  test('sin notas de modificación residuales', () {
    final nota = RegExp(r'D\.O\.? ?\d|LEY N[º°] ?\d');
    expect(ley.articulos.where((a) => nota.hasMatch(a.texto)).map((a) => a.numero),
        isEmpty);
  });

  test('artículos clave para fiscalización', () {
    expect(ley.articulo('6')!.texto, contains('llevar consigo su licencia'));
    expect(ley.articulo('51')!.texto, contains('seguro obligatorio'));
    expect(ley.articulo('89')!.texto, contains('revisión técnica'));
    expect(ley.articulo('5'), isNotNull);
  });

  test('búsqueda y temas', () {
    expect(ley.buscar('casco'), isNotEmpty);
    expect(ley.buscar('art 199').first.numero, '199');
    expect(ley.deTema(TemaLey.motos), isNotEmpty);
    expect(ley.deTema(TemaLey.documentos).map((a) => a.numero), contains('51'));
  });
}
