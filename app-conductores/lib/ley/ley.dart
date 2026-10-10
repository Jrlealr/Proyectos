import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'multas.dart';

/// Temas para navegar la ley. Los artículos se etiquetan automáticamente
/// por palabras clave en `tool/ley/convertir.py`.
enum TemaLey {
  documentos('Documentos obligatorios', 'documentos'),
  fiscalizacion('Fiscalización y retiro del vehículo', 'fiscalizacion'),
  infracciones('Infracciones y multas', 'infracciones'),
  velocidad('Velocidad', 'velocidad'),
  alcohol('Alcohol y drogas', 'alcohol'),
  celular('Celular y distracciones', 'celular'),
  motos('Motocicletas', 'motos'),
  licencias('Licencias de conducir', 'licencias');

  const TemaLey(this.nombre, this.clave);
  final String nombre;
  final String clave;
}

class Articulo {
  const Articulo({
    required this.id,
    required this.numero,
    required this.ubicacion,
    required this.texto,
    required this.temas,
  });

  final String id;

  /// Ej. "1", "96 bis", "Transitorio 2".
  final String numero;

  /// Título / párrafo al que pertenece (ej. "TÍTULO XIII - De la velocidad").
  final String ubicacion;
  final String texto;
  final Set<String> temas;

  factory Articulo.fromJson(Map<String, dynamic> j) => Articulo(
        id: j['id'] as String,
        numero: j['numero'] as String,
        ubicacion: j['ubicacion'] as String? ?? '',
        texto: j['texto'] as String,
        temas: (j['temas'] as List? ?? []).cast<String>().toSet(),
      );
}

class Ley {
  Ley({
    required this.titulo,
    required this.norma,
    required this.fuente,
    required this.versionFecha,
    required this.obtenido,
    required this.articulos,
    this.multas,
  }) : _indice = [for (final a in articulos) normalizarTexto('${a.numero} ${a.texto}')];

  final String titulo;
  final String norma;
  final String fuente;

  /// Fecha de la última modificación según LeyChile (texto, tal cual).
  final String versionFecha;

  /// Cuándo se descargó desde LeyChile (ISO 8601).
  final String obtenido;
  final List<Articulo> articulos;

  /// Tabla de infracciones y escala de multas (arts. 199–204).
  final TablaMultas? multas;
  final List<String> _indice;

  factory Ley.fromJson(Map<String, dynamic> j) => Ley(
        titulo: j['titulo'] as String,
        norma: j['norma'] as String,
        fuente: j['fuente'] as String,
        versionFecha: j['versionFecha'] as String? ?? '',
        obtenido: j['obtenido'] as String? ?? '',
        articulos: (j['articulos'] as List)
            .map((a) => Articulo.fromJson(a as Map<String, dynamic>))
            .toList(),
        multas: j['multas'] == null
            ? null
            : TablaMultas.fromJson(j['multas'] as Map<String, dynamic>),
      );

  static const ruta = 'assets/ley/ley_18290.json';

  /// null si el texto aún no está empaquetado en la app.
  static Future<Ley?> cargar() async {
    try {
      return Ley.fromJson(
          jsonDecode(await rootBundle.loadString(ruta)) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  List<Articulo> deTema(TemaLey tema) =>
      articulos.where((a) => a.temas.contains(tema.clave)).toList();

  Articulo? articulo(String numero) {
    final n = normalizarTexto(numero);
    return articulos.where((a) => normalizarTexto(a.numero) == n).firstOrNull;
  }

  /// Búsqueda por palabras (todas deben aparecer), sin distinguir tildes ni
  /// mayúsculas. "art 96" o "96" también encuentra el artículo por número.
  List<Articulo> buscar(String consulta) {
    final q = normalizarTexto(consulta)
        .replaceFirst(RegExp(r'^(articulo|art\.?)\s+'), '')
        .trim();
    if (q.isEmpty) return const [];
    final porNumero = articulo(q);
    final palabras = q.split(RegExp(r'\s+'));
    return [
      ?porNumero,
      for (var i = 0; i < articulos.length; i++)
        if (articulos[i] != porNumero &&
            palabras.every((p) => _indice[i].contains(p)))
          articulos[i],
    ];
  }
}

const _sinTilde = {
  'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n',
  'à': 'a', 'è': 'e', 'ì': 'i', 'ò': 'o', 'ù': 'u',
};

String normalizarTexto(String s) {
  final b = StringBuffer();
  for (final c in s.toLowerCase().split('')) {
    b.write(_sinTilde[c] ?? c);
  }
  return b.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}
