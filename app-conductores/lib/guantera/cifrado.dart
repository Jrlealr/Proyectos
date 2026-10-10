import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Entrega la clave maestra de 256 bits usada para cifrar la guantera.
abstract class ProveedorClave {
  Future<List<int>> clave();
}

/// Guarda la clave en el almacén seguro del sistema
/// (Android Keystore / iOS Keychain). Se genera la primera vez.
class ClaveAlmacenSeguro implements ProveedorClave {
  ClaveAlmacenSeguro([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _nombre = 'guantera_clave_v1';
  final FlutterSecureStorage _storage;
  List<int>? _cache;

  @override
  Future<List<int>> clave() async {
    if (_cache != null) return _cache!;
    final guardada = await _storage.read(key: _nombre);
    if (guardada != null) return _cache = base64Decode(guardada);
    final nueva = await AesGcm.with256bits().newSecretKey();
    final bytes = await nueva.extractBytes();
    await _storage.write(key: _nombre, value: base64Encode(bytes));
    return _cache = bytes;
  }
}

/// Cifrado AES-256-GCM. Formato: nonce (12) + texto cifrado + MAC (16).
class Cifrador {
  Cifrador(this._proveedor);

  final ProveedorClave _proveedor;
  final _algoritmo = AesGcm.with256bits();

  Future<Uint8List> cifrar(List<int> datos) async {
    final clave = SecretKey(await _proveedor.clave());
    final caja = await _algoritmo.encrypt(datos, secretKey: clave);
    return caja.concatenation();
  }

  Future<Uint8List> descifrar(List<int> datos) async {
    final clave = SecretKey(await _proveedor.clave());
    final caja = SecretBox.fromConcatenation(
      datos,
      nonceLength: _algoritmo.nonceLength,
      macLength: _algoritmo.macAlgorithm.macLength,
    );
    return Uint8List.fromList(await _algoritmo.decrypt(caja, secretKey: clave));
  }
}
