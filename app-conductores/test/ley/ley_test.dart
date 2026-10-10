import 'package:flutter_test/flutter_test.dart';

import 'package:flutter/painting.dart';

import 'package:app_conductores/ley/ley.dart';
import 'package:app_conductores/ui/ley.dart';

Ley _ley() => Ley.fromJson({
      'titulo': 'Ley de Tránsito',
      'norma': 'DFL 1',
      'fuente': 'https://www.bcn.cl/leychile/navegar?idNorma=1007469',
      'versionFecha': '2026-01-01',
      'obtenido': '2026-10-10',
      'articulos': [
        {'id': 'a1', 'numero': '1', 'ubicacion': 'TÍTULO I', 'texto': 'Las normas de esta ley regirán el tránsito.', 'temas': []},
        {'id': 'a2', 'numero': '96', 'ubicacion': 'TÍTULO V', 'texto': 'Los conductores deberán portar licencia y permiso de circulación.', 'temas': ['documentos']},
        {'id': 'a3', 'numero': '96 bis', 'ubicacion': 'TÍTULO V', 'texto': 'Motocicletas: casco obligatorio.', 'temas': ['motos']},
      ],
    });

void main() {
  test('normaliza tildes, mayúsculas y espacios', () {
    expect(normalizarTexto('  Circulación  ÑANDÚ '), 'circulacion nandu');
  });

  test('busca por palabras sin tildes', () {
    final r = _ley().buscar('permiso circulacion');
    expect(r.map((a) => a.numero), ['96']);
    expect(_ley().buscar('casco licencia'), isEmpty);
  });

  test('busca por número de artículo primero', () {
    expect(_ley().buscar('art 96').first.numero, '96');
    expect(_ley().buscar('Artículo 96 bis').first.numero, '96 bis');
    expect(_ley().buscar('1').first.numero, '1');
  });

  test('temas', () {
    expect(_ley().deTema(TemaLey.motos).single.numero, '96 bis');
    expect(_ley().deTema(TemaLey.alcohol), isEmpty);
  });

  test('resaltar sin tildes conserva el texto', () {
    final spans = resaltarTexto('Uso del casco en motocicletas', 'CASCO', const Color(0xFF00FF00));
    expect(spans.map((s) => s.text).join(), 'Uso del casco en motocicletas');
    expect(spans.where((s) => s.style != null).single.text, 'casco');
  });
}
