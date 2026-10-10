import 'guantera.dart';
import 'modelos.dart';

/// Documentos que la Ley de Tránsito exige portar al conducir.
const obligatorios = [
  TipoDocumento.licencia,
  TipoDocumento.permisoCirculacion,
  TipoDocumento.revisionTecnica,
  TipoDocumento.soap,
  TipoDocumento.padron,
];

/// Otros documentos que se muestran si el usuario los guardó.
const complementarios = [
  TipoDocumento.seguroVoluntario,
  TipoDocumento.cedula,
];

class ItemFiscalizacion {
  const ItemFiscalizacion(this.tipo, this.documento, {required this.obligatorio});
  final TipoDocumento tipo;

  /// null = el usuario no lo ha guardado.
  final Documento? documento;
  final bool obligatorio;
}

/// Entre varios documentos del mismo tipo, el de vencimiento más lejano
/// (o el más reciente si no tienen fecha).
Documento? _mejor(Iterable<Documento> docs) {
  Documento? mejor;
  for (final d in docs) {
    if (mejor == null) {
      mejor = d;
      continue;
    }
    final a = d.vencimiento, b = mejor.vencimiento;
    final esMejor = (a != null && b != null)
        ? a.isAfter(b)
        : (a == null && b == null)
            ? d.creado.isAfter(mejor.creado)
            : a != null;
    if (esMejor) mejor = d;
  }
  return mejor;
}

/// Lista ordenada para el Modo Fiscalización: primero los obligatorios
/// (estén o no guardados), luego los complementarios que existan.
List<ItemFiscalizacion> itemsFiscalizacion(Guantera g, String? vehiculoId) {
  final disponibles = [
    ...g.documentosDe(null),
    if (vehiculoId != null) ...g.documentosDe(vehiculoId),
  ];
  Documento? de(TipoDocumento t) => _mejor(disponibles.where((d) => d.tipo == t));
  return [
    for (final t in obligatorios)
      ItemFiscalizacion(t, de(t), obligatorio: true),
    for (final t in complementarios)
      if (de(t) case final d?) ItemFiscalizacion(t, d, obligatorio: false),
  ];
}
