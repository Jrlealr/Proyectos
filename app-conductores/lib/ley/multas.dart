import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';

import 'ley.dart';

/// Gravedad de una infracción (arts. 199 a 202 de la Ley 18.290).
enum Gravedad {
  gravisima('Gravísima', 'gravisima', '199'),
  grave('Grave', 'grave', '200'),
  menosGrave('Menos grave', 'menos_grave', '201'),
  leve('Leve', 'leve', '202');

  const Gravedad(this.nombre, this.clave, this.articulo);
  final String nombre;
  final String clave;

  /// Artículo que la define.
  final String articulo;

  static Gravedad deClave(String c) => values.firstWhere((g) => g.clave == c);
}

class RangoUtm {
  const RangoUtm(this.min, this.max);
  final double min;
  final double max;
}

class Infraccion {
  const Infraccion({
    required this.gravedad,
    required this.articulo,
    required this.numero,
    required this.texto,
  });

  final Gravedad gravedad;
  final String articulo;
  final int numero;
  final String texto;

  /// Referencia corta, ej. "Art. 200 N° 5".
  String get referencia => 'Art. $articulo N° $numero';
}

class TablaMultas {
  TablaMultas({required this.escala, required this.infracciones, this.notas = const {}})
      : _indice = [for (final i in infracciones) normalizarTexto(i.texto)];

  /// Rango en UTM por gravedad (art. 204).
  final Map<Gravedad, RangoUtm> escala;
  final List<Infraccion> infracciones;

  /// Incisos finales de los arts. 199–201 (excepciones a la tabla).
  final Map<String, List<String>> notas;
  final List<String> _indice;

  factory TablaMultas.fromJson(Map<String, dynamic> j) => TablaMultas(
        escala: {
          for (final MapEntry(:key, :value) in (j['escala'] as Map<String, dynamic>).entries)
            Gravedad.deClave(key): RangoUtm(
              ((value as Map)['minUtm'] as num).toDouble(),
              (value['maxUtm'] as num).toDouble(),
            ),
        },
        infracciones: [
          for (final i in j['infracciones'] as List)
            Infraccion(
              gravedad: Gravedad.deClave((i as Map)['gravedad'] as String),
              articulo: i['articulo'] as String,
              numero: i['numero'] as int,
              texto: i['texto'] as String,
            ),
        ],
        notas: {
          for (final MapEntry(:key, :value)
              in ((j['notas'] as Map<String, dynamic>?) ?? {}).entries)
            key: (value as List).cast<String>(),
        },
      );

  List<Infraccion> de(Gravedad g) =>
      infracciones.where((i) => i.gravedad == g).toList();

  /// Búsqueda por palabras sin tildes; "200 5" o "art 200 n 5" busca por número.
  List<Infraccion> buscar(String consulta) {
    final q = normalizarTexto(consulta);
    if (q.isEmpty) return infracciones;
    final ref = RegExp(r'^(?:art\.?\s*)?(\d{3})\s*(?:n[°º]?\.?\s*)?(\d+)$').firstMatch(q);
    if (ref != null) {
      return infracciones
          .where((i) => i.articulo == ref[1] && i.numero == int.parse(ref[2]!))
          .toList();
    }
    final palabras = q.split(' ');
    return [
      for (var k = 0; k < infracciones.length; k++)
        if (palabras.every(_indice[k].contains)) infracciones[k],
    ];
  }
}

/// Valor de la UTM usado para convertir a pesos.
class Utm {
  const Utm({required this.valor, required this.mes, required this.fuente});
  final int valor;

  /// "AAAA-MM".
  final String mes;
  final String fuente;

  static Future<Utm?> cargar() async {
    try {
      final j = jsonDecode(await rootBundle.loadString('assets/ley/utm.json'))
          as Map<String, dynamic>;
      return Utm(
          valor: j['valor'] as int, mes: j['mes'] as String, fuente: j['fuente'] as String);
    } catch (_) {
      return null;
    }
  }

  static final _miles = NumberFormat('#,##0', 'es_CL');

  /// Monto redondeado al peso, formato chileno (ej. "$102.000").
  String pesos(double utm) => '\$${_miles.format((utm * valor).round())}';

  String rango(RangoUtm r) => '${pesos(r.min)} a ${pesos(r.max)}';
}

final _utm = NumberFormat('#,##0.##', 'es_CL');

/// Ej. 1.5 → "1,5 UTM".
String formatoUtm(double v) => '${_utm.format(v)} UTM';
