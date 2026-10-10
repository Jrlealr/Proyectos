/// Modelo de los puntos de oferta definidos en `assets/config/ofertas.json`.
/// Ver docs/puntos-de-oferta.md.
class ConfigOfertas {
  const ConfigOfertas({
    required this.version,
    required this.habilitadas,
    required this.etiqueta,
    required this.ofertas,
  });

  final int version;

  /// Flag global: si es false no se muestra ninguna oferta.
  final bool habilitadas;
  final String etiqueta;
  final List<Oferta> ofertas;

  factory ConfigOfertas.fromJson(Map<String, dynamic> json) => ConfigOfertas(
        version: json['version'] as int,
        habilitadas: json['habilitadas'] as bool? ?? false,
        etiqueta: json['etiqueta'] as String? ?? 'Patrocinado',
        ofertas: (json['ofertas'] as List<dynamic>? ?? [])
            .map((o) => Oferta.fromJson(o as Map<String, dynamic>))
            .toList(),
      );

  /// Config segura por defecto si el archivo falta o está corrupto.
  static const desactivada = ConfigOfertas(
    version: 0,
    habilitadas: false,
    etiqueta: 'Patrocinado',
    ofertas: [],
  );
}

class Oferta {
  const Oferta({
    required this.id,
    required this.habilitada,
    required this.ubicacion,
    required this.disparador,
    required this.texto,
    required this.datosCompartidos,
    this.documento,
    this.urlDestino,
  });

  final String id;
  final bool habilitada;
  final String ubicacion;
  final String? documento;
  final Disparador disparador;
  final String texto;
  final String? urlDestino;

  /// Únicos datos que salen del dispositivo, y solo tras tocar + consentir.
  final List<String> datosCompartidos;

  factory Oferta.fromJson(Map<String, dynamic> json) => Oferta(
        id: json['id'] as String,
        habilitada: json['habilitada'] as bool? ?? false,
        ubicacion: json['ubicacion'] as String,
        documento: json['documento'] as String?,
        disparador: Disparador.fromJson(
            json['disparador'] as Map<String, dynamic>? ?? const {}),
        texto: json['texto'] as String,
        urlDestino: json['urlDestino'] as String?,
        datosCompartidos:
            (json['datosCompartidos'] as List<dynamic>? ?? []).cast<String>(),
      );
}

class Disparador {
  const Disparador({
    this.diasAntesVencimiento,
    this.incluirVencido = false,
    this.sinSeguroVoluntario = false,
    this.parteRegistrado = false,
    this.recordatorioMantencion = false,
  });

  final int? diasAntesVencimiento;
  final bool incluirVencido;
  final bool sinSeguroVoluntario;
  final bool parteRegistrado;
  final bool recordatorioMantencion;

  factory Disparador.fromJson(Map<String, dynamic> json) => Disparador(
        diasAntesVencimiento: json['diasAntesVencimiento'] as int?,
        incluirVencido: json['incluirVencido'] as bool? ?? false,
        sinSeguroVoluntario: json['sinSeguroVoluntario'] as bool? ?? false,
        parteRegistrado: json['parteRegistrado'] as bool? ?? false,
        recordatorioMantencion: json['recordatorioMantencion'] as bool? ?? false,
      );
}
