import 'package:intl/intl.dart';

/// Registro de un control policial o de inspectores, como respaldo para
/// presentar descargos ante el Juzgado de Policía Local.

enum Institucion {
  carabineros('Carabineros de Chile'),
  inspectorMunicipal('Inspector municipal'),
  inspectorFiscal('Inspector fiscal (MTT)'),
  otra('Otra');

  const Institucion(this.nombre);
  final String nombre;
}

enum ResultadoControl {
  sinInfraccion('Sin infracción'),
  citacion('Citación al Juzgado (parte)'),
  retiroVehiculo('Retiro del vehículo'),
  otro('Otro');

  const ResultadoControl(this.nombre);
  final String nombre;

  bool get conCitacion =>
      this == ResultadoControl.citacion || this == ResultadoControl.retiroVehiculo;
}

class Adjunto {
  const Adjunto({required this.archivoId, required this.esPdf, required this.nombre});
  final String archivoId;
  final bool esPdf;
  final String nombre;

  Map<String, dynamic> toJson() =>
      {'archivoId': archivoId, 'esPdf': esPdf, 'nombre': nombre};

  factory Adjunto.fromJson(Map<String, dynamic> j) => Adjunto(
        archivoId: j['archivoId'] as String,
        esPdf: j['esPdf'] as bool,
        nombre: j['nombre'] as String,
      );
}

class Control {
  const Control({
    required this.id,
    required this.fechaHora,
    this.vehiculoId,
    this.patente = '',
    this.lugar = '',
    this.latitud,
    this.longitud,
    this.institucion = Institucion.carabineros,
    this.funcionarioNombre = '',
    this.funcionarioGrado = '',
    this.funcionarioIdentificacion = '',
    this.motivo = '',
    this.resultado = ResultadoControl.sinInfraccion,
    this.numeroCitacion = '',
    this.juzgado = '',
    this.fechaComparecencia,
    this.infracciones = '',
    this.adjuntos = const [],
    this.notas = '',
  });

  final String id;
  final DateTime fechaHora;
  final String? vehiculoId;

  /// Copia de la patente al momento del control (sobrevive si se borra el vehículo).
  final String patente;
  final String lugar;
  final double? latitud;
  final double? longitud;
  final Institucion institucion;
  final String funcionarioNombre;
  final String funcionarioGrado;
  final String funcionarioIdentificacion;
  final String motivo;
  final ResultadoControl resultado;
  final String numeroCitacion;
  final String juzgado;

  /// Día y hora en que hay que presentarse al Juzgado (si la hay).
  final DateTime? fechaComparecencia;
  final String infracciones;
  final List<Adjunto> adjuntos;
  final String notas;

  Control copyWith({List<Adjunto>? adjuntos}) => Control(
        id: id,
        fechaHora: fechaHora,
        vehiculoId: vehiculoId,
        patente: patente,
        lugar: lugar,
        latitud: latitud,
        longitud: longitud,
        institucion: institucion,
        funcionarioNombre: funcionarioNombre,
        funcionarioGrado: funcionarioGrado,
        funcionarioIdentificacion: funcionarioIdentificacion,
        motivo: motivo,
        resultado: resultado,
        numeroCitacion: numeroCitacion,
        juzgado: juzgado,
        fechaComparecencia: fechaComparecencia,
        infracciones: infracciones,
        adjuntos: adjuntos ?? this.adjuntos,
        notas: notas,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'fechaHora': fechaHora.toIso8601String(),
        'vehiculoId': vehiculoId,
        'patente': patente,
        'lugar': lugar,
        'latitud': latitud,
        'longitud': longitud,
        'institucion': institucion.name,
        'funcionarioNombre': funcionarioNombre,
        'funcionarioGrado': funcionarioGrado,
        'funcionarioIdentificacion': funcionarioIdentificacion,
        'motivo': motivo,
        'resultado': resultado.name,
        'numeroCitacion': numeroCitacion,
        'juzgado': juzgado,
        'fechaComparecencia': fechaComparecencia?.toIso8601String(),
        'infracciones': infracciones,
        'adjuntos': adjuntos.map((a) => a.toJson()).toList(),
        'notas': notas,
      };

  factory Control.fromJson(Map<String, dynamic> j) => Control(
        id: j['id'] as String,
        fechaHora: DateTime.parse(j['fechaHora'] as String),
        vehiculoId: j['vehiculoId'] as String?,
        patente: j['patente'] as String? ?? '',
        lugar: j['lugar'] as String? ?? '',
        latitud: (j['latitud'] as num?)?.toDouble(),
        longitud: (j['longitud'] as num?)?.toDouble(),
        institucion: Institucion.values.byName(j['institucion'] as String),
        funcionarioNombre: j['funcionarioNombre'] as String? ?? '',
        funcionarioGrado: j['funcionarioGrado'] as String? ?? '',
        funcionarioIdentificacion: j['funcionarioIdentificacion'] as String? ?? '',
        motivo: j['motivo'] as String? ?? '',
        resultado: ResultadoControl.values.byName(j['resultado'] as String),
        numeroCitacion: j['numeroCitacion'] as String? ?? '',
        juzgado: j['juzgado'] as String? ?? '',
        fechaComparecencia: j['fechaComparecencia'] == null
            ? null
            : DateTime.parse(j['fechaComparecencia'] as String),
        infracciones: j['infracciones'] as String? ?? '',
        adjuntos: (j['adjuntos'] as List? ?? [])
            .map((a) => Adjunto.fromJson(a as Map<String, dynamic>))
            .toList(),
        notas: j['notas'] as String? ?? '',
      );
}

final _fechaHora = DateFormat('dd-MM-yyyy HH:mm');

/// Texto plano del registro, para copiar en un escrito de descargos.
String resumenControl(Control c) {
  final l = <String>[
    'REGISTRO DE CONTROL',
    'Fecha y hora: ${_fechaHora.format(c.fechaHora)}',
    if (c.patente.isNotEmpty) 'Vehículo (patente): ${c.patente}',
    if (c.lugar.isNotEmpty) 'Lugar: ${c.lugar}',
    if (c.latitud != null && c.longitud != null)
      'Coordenadas: ${c.latitud!.toStringAsFixed(6)}, ${c.longitud!.toStringAsFixed(6)}',
    'Institución: ${c.institucion.nombre}',
    if (c.funcionarioGrado.isNotEmpty || c.funcionarioNombre.isNotEmpty)
      'Funcionario: ${[c.funcionarioGrado, c.funcionarioNombre].where((s) => s.isNotEmpty).join(' ')}',
    if (c.funcionarioIdentificacion.isNotEmpty)
      'Identificación del funcionario: ${c.funcionarioIdentificacion}',
    if (c.motivo.isNotEmpty) 'Motivo indicado: ${c.motivo}',
    'Resultado: ${c.resultado.nombre}',
    if (c.numeroCitacion.isNotEmpty) 'N° de citación: ${c.numeroCitacion}',
    if (c.infracciones.isNotEmpty) 'Infracción imputada: ${c.infracciones}',
    if (c.juzgado.isNotEmpty) 'Juzgado: ${c.juzgado}',
    if (c.fechaComparecencia != null)
      'Comparecencia: ${_fechaHora.format(c.fechaComparecencia!)}',
    if (c.adjuntos.isNotEmpty) 'Adjuntos: ${c.adjuntos.length} archivo(s)',
    if (c.notas.isNotEmpty) 'Notas: ${c.notas}',
  ];
  return l.join('\n');
}
