import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:app_conductores/ley/ley.dart';
import 'package:app_conductores/ley/multas.dart';

void main() {
  final ley = Ley.fromJson(jsonDecode(File('assets/ley/ley_18290.json').readAsStringSync())
      as Map<String, dynamic>);
  final tabla = ley.multas!;

  test('escala del art. 204', () {
    expect(tabla.escala.length, 4);
    expect([tabla.escala[Gravedad.gravisima]!.min, tabla.escala[Gravedad.gravisima]!.max], [1.5, 3]);
    expect([tabla.escala[Gravedad.grave]!.min, tabla.escala[Gravedad.grave]!.max], [1, 1.5]);
    expect([tabla.escala[Gravedad.menosGrave]!.min, tabla.escala[Gravedad.menosGrave]!.max], [0.5, 1]);
    expect([tabla.escala[Gravedad.leve]!.min, tabla.escala[Gravedad.leve]!.max], [0.2, 0.5]);
  });

  test('infracciones enumeradas sin saltos', () {
    for (final g in [Gravedad.gravisima, Gravedad.grave, Gravedad.menosGrave]) {
      final ns = tabla.de(g).map((i) => i.numero).toList();
      expect(ns, List.generate(ns.length, (k) => k + 1), reason: g.nombre);
      expect(ns.length, greaterThanOrEqualTo(5));
    }
    expect(tabla.de(Gravedad.leve), isEmpty);
    expect(tabla.infracciones.every((i) => i.articulo == i.gravedad.articulo), isTrue);
  });

  test('incisos finales separados de los ítems', () {
    expect(tabla.notas['200']!.single, startsWith('En los casos de las infracciones'));
    expect(tabla.infracciones.any((i) => i.texto.contains('En los casos de las infracciones')),
        isFalse);
  });

  test('búsqueda por texto y por referencia', () {
    final celular = tabla.buscar('telefonia movil');
    expect(celular.map((i) => i.referencia), contains('Art. 199 N° 5'));
    expect(tabla.buscar('200 5').single.referencia, 'Art. 200 N° 5');
    expect(tabla.buscar('Art 201 N° 2').single.referencia, 'Art. 201 N° 2');
    expect(tabla.buscar('').length, tabla.infracciones.length);
  });

  test('conversión a pesos', () {
    const utm = Utm(valor: 68000, mes: '2026-10', fuente: 'prueba');
    expect(utm.pesos(1.5), r'$102.000');
    expect(utm.rango(const RangoUtm(0.2, 0.5)), r'$13.600 a $34.000');
    expect(formatoUtm(1.5), '1,5 UTM');
    expect(formatoUtm(3), '3 UTM');
  });

  test('UTM empaquetada válida', () {
    final j = jsonDecode(File('assets/ley/utm.json').readAsStringSync()) as Map<String, dynamic>;
    expect(j['valor'], inInclusiveRange(50000, 200000));
    expect(j['mes'], matches(RegExp(r'^\d{4}-\d{2}$')));
  });
}
