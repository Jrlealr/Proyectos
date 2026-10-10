import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'cifrado.dart';
import 'modelos.dart';

class DatosGuantera {
  DatosGuantera({
    List<Vehiculo>? vehiculos,
    List<Documento>? documentos,
    this.permiteOfertas = true,
    Set<String>? ofertasDescartadas,
  })  : vehiculos = vehiculos ?? [],
        documentos = documentos ?? [],
        ofertasDescartadas = ofertasDescartadas ?? {};

  final List<Vehiculo> vehiculos;
  final List<Documento> documentos;

  /// Interruptor de Ajustes → "Ofertas y beneficios".
  bool permiteOfertas;

  /// Claves "ofertaId:documentoId:vencimiento" descartadas por el usuario.
  final Set<String> ofertasDescartadas;

  Map<String, dynamic> toJson() => {
        'version': 1,
        'vehiculos': vehiculos.map((v) => v.toJson()).toList(),
        'documentos': documentos.map((d) => d.toJson()).toList(),
        'permiteOfertas': permiteOfertas,
        'ofertasDescartadas': ofertasDescartadas.toList(),
      };

  factory DatosGuantera.fromJson(Map<String, dynamic> j) => DatosGuantera(
        vehiculos: (j['vehiculos'] as List? ?? [])
            .map((v) => Vehiculo.fromJson(v as Map<String, dynamic>))
            .toList(),
        documentos: (j['documentos'] as List? ?? [])
            .map((d) => Documento.fromJson(d as Map<String, dynamic>))
            .toList(),
        permiteOfertas: j['permiteOfertas'] as bool? ?? true,
        ofertasDescartadas:
            (j['ofertasDescartadas'] as List? ?? []).cast<String>().toSet(),
      );
}

/// Persistencia local cifrada: un índice (`guantera.bin`) y un archivo
/// cifrado por documento en `docs/`. Nada sale del dispositivo.
class AlmacenGuantera {
  AlmacenGuantera(this.directorio, this._cifrador);

  final Directory directorio;
  final Cifrador _cifrador;
  final _random = Random.secure();

  File get _indice => File('${directorio.path}/guantera.bin');
  Directory get _docs => Directory('${directorio.path}/docs');

  String nuevoId() {
    final bytes = List<int>.generate(12, (_) => _random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Si el índice no se puede descifrar (ej. se perdió la clave al
  /// reinstalar), se aparta con otro nombre en vez de sobrescribirlo y se
  /// parte con una guantera vacía.
  Future<DatosGuantera> cargar() async {
    if (!await _indice.exists()) return DatosGuantera();
    try {
      final claro = await _cifrador.descifrar(await _indice.readAsBytes());
      return DatosGuantera.fromJson(
          jsonDecode(utf8.decode(claro)) as Map<String, dynamic>);
    } catch (_) {
      final marca = DateTime.now().millisecondsSinceEpoch;
      await _indice.rename('${_indice.path}.ilegible-$marca');
      return DatosGuantera();
    }
  }

  Future<void> guardar(DatosGuantera datos) async {
    await directorio.create(recursive: true);
    final cifrado =
        await _cifrador.cifrar(utf8.encode(jsonEncode(datos.toJson())));
    // Escritura atómica: si la app se cierra a mitad, el índice no se corrompe.
    final tmp = File('${_indice.path}.tmp');
    await tmp.writeAsBytes(cifrado, flush: true);
    await tmp.rename(_indice.path);
  }

  Future<String> guardarArchivo(List<int> bytes) async {
    await _docs.create(recursive: true);
    final id = nuevoId();
    await File('${_docs.path}/$id.bin')
        .writeAsBytes(await _cifrador.cifrar(bytes), flush: true);
    return id;
  }

  Future<Uint8List> leerArchivo(String id) async =>
      _cifrador.descifrar(await File('${_docs.path}/$id.bin').readAsBytes());

  Future<void> borrarArchivo(String id) async {
    final f = File('${_docs.path}/$id.bin');
    if (await f.exists()) await f.delete();
  }
}
