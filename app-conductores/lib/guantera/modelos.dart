// Modelos de la guantera digital. Todo se guarda localmente y cifrado.

enum TipoVehiculo {
  auto('Auto'),
  moto('Moto');

  const TipoVehiculo(this.nombre);
  final String nombre;
}

enum TipoDocumento {
  licencia('Licencia de conducir', personal: true, vence: true),
  cedula('Cédula de identidad (RUT)', personal: true, vence: true),
  permisoCirculacion('Permiso de circulación', vence: true),
  revisionTecnica('Revisión técnica', vence: true),
  soap('SOAP', vence: true),
  padron('Padrón / Certificado de inscripción'),
  seguroVoluntario('Seguro automotriz', vence: true),
  fotoPatente('Foto placa patente'),
  otro('Otro documento', vence: true);

  const TipoDocumento(this.nombre, {this.personal = false, this.vence = false});
  final String nombre;

  /// Documento de la persona (no de un vehículo).
  final bool personal;

  /// Si normalmente tiene fecha de vencimiento.
  final bool vence;

  /// Clave usada por la config de ofertas (`documento`).
  String get clave => switch (this) {
        TipoDocumento.permisoCirculacion => 'permiso_circulacion',
        TipoDocumento.revisionTecnica => 'revision_tecnica',
        TipoDocumento.seguroVoluntario => 'seguro_voluntario',
        TipoDocumento.fotoPatente => 'foto_patente',
        _ => name,
      };

  /// Fotos de documentos físicos no reemplazan al documento ante un
  /// fiscalizador; solo los PDF originales con QR o la app oficial.
  String? get avisoValidez => switch (this) {
        TipoDocumento.licencia =>
          'Una foto no reemplaza la licencia física. La licencia digital válida '
              'está en la app oficial de Conaset.',
        TipoDocumento.cedula =>
          'Una foto de la cédula no reemplaza el documento físico.',
        TipoDocumento.permisoCirculacion ||
        TipoDocumento.revisionTecnica ||
        TipoDocumento.soap =>
          'Guarda el PDF original con código QR: es el que el fiscalizador '
              'puede verificar.',
        _ => null,
      };
}

class Vehiculo {
  const Vehiculo({
    required this.id,
    required this.patente,
    required this.tipo,
    this.marca = '',
    this.modelo = '',
    this.anio,
  });

  final String id;
  final String patente;
  final TipoVehiculo tipo;
  final String marca;
  final String modelo;
  final int? anio;

  String get descripcion =>
      [marca, modelo, if (anio != null) '$anio'].where((s) => s.isNotEmpty).join(' ');

  Map<String, dynamic> toJson() => {
        'id': id,
        'patente': patente,
        'tipo': tipo.name,
        'marca': marca,
        'modelo': modelo,
        'anio': anio,
      };

  factory Vehiculo.fromJson(Map<String, dynamic> j) => Vehiculo(
        id: j['id'] as String,
        patente: j['patente'] as String,
        tipo: TipoVehiculo.values.byName(j['tipo'] as String),
        marca: j['marca'] as String? ?? '',
        modelo: j['modelo'] as String? ?? '',
        anio: j['anio'] as int?,
      );
}

class Documento {
  const Documento({
    required this.id,
    required this.tipo,
    required this.archivoId,
    required this.esPdf,
    required this.nombreArchivo,
    required this.creado,
    this.vehiculoId,
    this.vencimiento,
    this.nota = '',
  });

  final String id;
  final TipoDocumento tipo;

  /// null = documento personal (licencia, cédula).
  final String? vehiculoId;

  /// Fecha (sin hora) hasta la que el documento es válido.
  final DateTime? vencimiento;
  final String archivoId;
  final bool esPdf;
  final String nombreArchivo;
  final DateTime creado;
  final String nota;

  Map<String, dynamic> toJson() => {
        'id': id,
        'tipo': tipo.name,
        'vehiculoId': vehiculoId,
        'vencimiento': vencimiento?.toIso8601String(),
        'archivoId': archivoId,
        'esPdf': esPdf,
        'nombreArchivo': nombreArchivo,
        'creado': creado.toIso8601String(),
        'nota': nota,
      };

  factory Documento.fromJson(Map<String, dynamic> j) => Documento(
        id: j['id'] as String,
        tipo: TipoDocumento.values.byName(j['tipo'] as String),
        vehiculoId: j['vehiculoId'] as String?,
        vencimiento: j['vencimiento'] == null
            ? null
            : DateTime.parse(j['vencimiento'] as String),
        archivoId: j['archivoId'] as String,
        esPdf: j['esPdf'] as bool,
        nombreArchivo: j['nombreArchivo'] as String,
        creado: DateTime.parse(j['creado'] as String),
        nota: j['nota'] as String? ?? '',
      );
}

enum EstadoVencimiento { sinVencimiento, vigente, porVencer, vencido }

/// Días antes del vencimiento en que un documento pasa a "por vencer".
const diasPorVencer = 30;

DateTime soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);

/// Días que faltan para el vencimiento (0 = vence hoy, negativo = vencido).
int? diasParaVencer(Documento d, DateTime hoy) {
  final v = d.vencimiento;
  if (v == null) return null;
  // Se usa UTC para que los cambios de horario no alteren la diferencia.
  final a = DateTime.utc(hoy.year, hoy.month, hoy.day);
  final b = DateTime.utc(v.year, v.month, v.day);
  return b.difference(a).inDays;
}

EstadoVencimiento estadoDe(Documento d, DateTime hoy) {
  final dias = diasParaVencer(d, hoy);
  if (dias == null) return EstadoVencimiento.sinVencimiento;
  if (dias < 0) return EstadoVencimiento.vencido;
  if (dias <= diasPorVencer) return EstadoVencimiento.porVencer;
  return EstadoVencimiento.vigente;
}

/// Permiso de circulación y SOAP de vehículos particulares vencen el 31 de
/// marzo. Se usa solo como sugerencia editable en el formulario.
DateTime? vencimientoSugerido(TipoDocumento tipo, DateTime hoy) {
  if (tipo != TipoDocumento.permisoCirculacion && tipo != TipoDocumento.soap) {
    return null;
  }
  final esteAnio = DateTime(hoy.year, 3, 31);
  return soloFecha(hoy).isAfter(esteAnio) ? DateTime(hoy.year + 1, 3, 31) : esteAnio;
}

/// Normaliza una patente chilena: mayúsculas, sin espacios, puntos ni guiones.
String normalizarPatente(String s) =>
    s.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

/// Validación laxa: 5 o 6 caracteres alfanuméricos que terminan en dígito.
/// Cubre formatos de autos (AB1234, BBBB12) y motos (AB123, BBB12).
bool patenteValida(String s) =>
    RegExp(r'^[A-Z]{2,4}[0-9]{1,4}$').hasMatch(s) && s.length >= 5 && s.length <= 6;
