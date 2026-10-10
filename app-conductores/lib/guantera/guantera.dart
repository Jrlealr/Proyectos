import 'package:flutter/foundation.dart';

import '../navegacion/navegacion.dart';
import 'alertas.dart';
import 'almacen.dart';
import 'control.dart';
import 'modelos.dart';

/// Estado de la guantera digital para la UI.
class Guantera extends ChangeNotifier {
  Guantera(this._almacen, this._alertas, {DateTime Function()? reloj})
      : _reloj = reloj ?? DateTime.now;

  final AlmacenGuantera _almacen;
  final Alertas _alertas;
  final DateTime Function() _reloj;
  DatosGuantera _datos = DatosGuantera();

  DateTime get hoy => soloFecha(_reloj());
  List<Vehiculo> get vehiculos => List.unmodifiable(_datos.vehiculos);
  bool get permiteOfertas => _datos.permiteOfertas;
  Set<String> get ofertasDescartadas => Set.unmodifiable(_datos.ofertasDescartadas);
  AppNavegacion get appNavegacion => _datos.appNavegacion;

  Future<void> cargar() async {
    _datos = await _almacen.cargar();
    notifyListeners();
  }

  Future<void> _guardar() async {
    await _almacen.guardar(_datos);
    notifyListeners();
  }

  Vehiculo? vehiculo(String? id) =>
      _datos.vehiculos.where((v) => v.id == id).firstOrNull;

  /// Documentos de un vehículo, o los personales si [vehiculoId] es null.
  List<Documento> documentosDe(String? vehiculoId) => _datos.documentos
      .where((d) => d.vehiculoId == vehiculoId)
      .toList()
    ..sort((a, b) => a.tipo.index.compareTo(b.tipo.index));

  /// Documentos con fecha, del más urgente al menos urgente.
  List<Documento> get vencimientos => _datos.documentos
      .where((d) => d.vencimiento != null)
      .toList()
    ..sort((a, b) => a.vencimiento!.compareTo(b.vencimiento!));

  /// Peor estado entre los documentos de un vehículo (para el ícono).
  EstadoVencimiento estadoVehiculo(String vehiculoId) => documentosDe(vehiculoId)
      .map((d) => estadoDe(d, hoy))
      .fold(EstadoVencimiento.sinVencimiento,
          (a, b) => a.index >= b.index ? a : b);

  Future<Vehiculo> guardarVehiculo({
    String? id,
    required String patente,
    required TipoVehiculo tipo,
    String marca = '',
    String modelo = '',
    int? anio,
  }) async {
    final v = Vehiculo(
      id: id ?? _almacen.nuevoId(),
      patente: normalizarPatente(patente),
      tipo: tipo,
      marca: marca.trim(),
      modelo: modelo.trim(),
      anio: anio,
    );
    final i = _datos.vehiculos.indexWhere((x) => x.id == v.id);
    if (i >= 0) {
      _datos.vehiculos[i] = v;
    } else {
      _datos.vehiculos.add(v);
    }
    await _guardar();
    // La patente aparece en el texto de las alertas.
    for (final d in documentosDe(v.id)) {
      await _alertas.programar(d, v.patente);
    }
    return v;
  }

  Future<void> borrarVehiculo(String id) async {
    for (final d in documentosDe(id)) {
      await _borrarDocumentoSinGuardar(d);
    }
    _datos.vehiculos.removeWhere((v) => v.id == id);
    await _guardar();
  }

  Future<Documento> agregarDocumento({
    required TipoDocumento tipo,
    String? vehiculoId,
    required Uint8List bytes,
    required bool esPdf,
    required String nombreArchivo,
    DateTime? vencimiento,
    String nota = '',
  }) async {
    final archivoId = await _almacen.guardarArchivo(bytes);
    final doc = Documento(
      id: _almacen.nuevoId(),
      tipo: tipo,
      vehiculoId: tipo.personal ? null : vehiculoId,
      vencimiento: vencimiento == null ? null : soloFecha(vencimiento),
      archivoId: archivoId,
      esPdf: esPdf,
      nombreArchivo: nombreArchivo,
      creado: _reloj(),
      nota: nota.trim(),
    );
    _datos.documentos.add(doc);
    await _guardar();
    await _alertas.programar(doc, vehiculo(doc.vehiculoId)?.patente);
    return doc;
  }

  /// Cambia la fecha de vencimiento (ej. tras renovar sin cambiar archivo).
  Future<void> actualizarVencimiento(Documento doc, DateTime? vencimiento) async {
    final i = _datos.documentos.indexWhere((d) => d.id == doc.id);
    if (i < 0) return;
    final nuevo = Documento(
      id: doc.id,
      tipo: doc.tipo,
      vehiculoId: doc.vehiculoId,
      vencimiento: vencimiento == null ? null : soloFecha(vencimiento),
      archivoId: doc.archivoId,
      esPdf: doc.esPdf,
      nombreArchivo: doc.nombreArchivo,
      creado: doc.creado,
      nota: doc.nota,
    );
    _datos.documentos[i] = nuevo;
    await _guardar();
    await _alertas.programar(nuevo, vehiculo(nuevo.vehiculoId)?.patente);
  }

  Future<void> borrarDocumento(Documento doc) async {
    await _borrarDocumentoSinGuardar(doc);
    await _guardar();
  }

  Future<void> _borrarDocumentoSinGuardar(Documento doc) async {
    await _alertas.cancelar(doc);
    await _almacen.borrarArchivo(doc.archivoId);
    _datos.documentos.removeWhere((d) => d.id == doc.id);
  }

  Future<Uint8List> leerArchivo(Documento doc) => _almacen.leerArchivo(doc.archivoId);

  /// Controles registrados, del más reciente al más antiguo.
  List<Control> get controles => [..._datos.controles]
    ..sort((a, b) => b.fechaHora.compareTo(a.fechaHora));

  Control? control(String id) =>
      _datos.controles.where((c) => c.id == id).firstOrNull;

  String nuevoId() => _almacen.nuevoId();

  /// Crea o reemplaza un control. [nuevosAdjuntos] se cifran y se agregan.
  Future<Control> guardarControl(
    Control c, {
    List<(Uint8List bytes, bool esPdf, String nombre)> nuevosAdjuntos = const [],
  }) async {
    final adjuntos = [...c.adjuntos];
    for (final (bytes, esPdf, nombre) in nuevosAdjuntos) {
      adjuntos.add(Adjunto(
          archivoId: await _almacen.guardarArchivo(bytes), esPdf: esPdf, nombre: nombre));
    }
    final previo = control(c.id);
    // Adjuntos quitados en la edición: se borran del disco.
    for (final a in previo?.adjuntos ?? const <Adjunto>[]) {
      if (!adjuntos.any((x) => x.archivoId == a.archivoId)) {
        await _almacen.borrarArchivo(a.archivoId);
      }
    }
    final nuevo = c.copyWith(adjuntos: adjuntos);
    _datos.controles
      ..removeWhere((x) => x.id == c.id)
      ..add(nuevo);
    await _guardar();
    await _alertas.programarControl(nuevo);
    return nuevo;
  }

  Future<void> borrarControl(Control c) async {
    await _alertas.cancelarControl(c);
    for (final a in c.adjuntos) {
      await _almacen.borrarArchivo(a.archivoId);
    }
    _datos.controles.removeWhere((x) => x.id == c.id);
    await _guardar();
  }

  Future<Uint8List> leerAdjunto(Adjunto a) => _almacen.leerArchivo(a.archivoId);

  Future<void> cambiarPermiteOfertas(bool valor) async {
    _datos.permiteOfertas = valor;
    await _guardar();
  }

  Future<void> cambiarAppNavegacion(AppNavegacion app) async {
    _datos.appNavegacion = app;
    await _guardar();
  }

  Future<void> descartarOferta(String clave) async {
    _datos.ofertasDescartadas.add(clave);
    await _guardar();
  }
}
