// Enlaces a Google Maps y Waze. Se usan enlaces universales (https): abren
// la app si está instalada y, si no, el navegador. No requieren API key.
//
// Privacidad: solo se envía a Google/Waze el destino que el usuario elige
// abrir (texto de búsqueda o coordenadas), en el momento en que lo toca.

enum AppNavegacion {
  preguntar('Preguntar cada vez'),
  googleMaps('Google Maps'),
  waze('Waze');

  const AppNavegacion(this.nombre);
  final String nombre;
}

sealed class Destino {
  const Destino();
}

/// Búsqueda por texto, ej. "Juzgado de Policía Local Providencia".
class DestinoBusqueda extends Destino {
  const DestinoBusqueda(this.texto);
  final String texto;
}

/// Punto exacto, ej. el lugar de un control con GPS.
class DestinoCoordenadas extends Destino {
  const DestinoCoordenadas(this.latitud, this.longitud);
  final double latitud;
  final double longitud;
}

Uri uriNavegacion(AppNavegacion app, Destino destino) {
  assert(app != AppNavegacion.preguntar);
  return switch ((app, destino)) {
    (AppNavegacion.waze, DestinoBusqueda(:final texto)) =>
      Uri.https('waze.com', '/ul', {'q': texto, 'navigate': 'yes'}),
    (AppNavegacion.waze, DestinoCoordenadas(:final latitud, :final longitud)) =>
      Uri.https('waze.com', '/ul', {'ll': '$latitud,$longitud', 'navigate': 'yes'}),
    (_, DestinoBusqueda(:final texto)) =>
      Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': texto}),
    (_, DestinoCoordenadas(:final latitud, :final longitud)) =>
      Uri.https('www.google.com', '/maps/dir/',
          {'api': '1', 'destination': '$latitud,$longitud', 'travelmode': 'driving'}),
  };
}

/// Lugares útiles para el conductor, buscados "cerca de mí" por el mapa.
class LugaresUtiles {
  static const plantaRevisionTecnica = DestinoBusqueda('planta de revisión técnica');
  static const direccionTransito = DestinoBusqueda('Dirección de Tránsito municipalidad');
  static const juzgadoPoliciaLocal = DestinoBusqueda('Juzgado de Policía Local');

  /// Si el usuario escribió el juzgado ("1° JPL de Providencia"), se busca
  /// tal cual; si no, el más cercano.
  static Destino juzgado(String nombre) {
    final n = nombre.trim();
    if (n.isEmpty) return juzgadoPoliciaLocal;
    final pareceJuzgado = RegExp(r'juzgado|jpl', caseSensitive: false).hasMatch(n);
    return DestinoBusqueda(pareceJuzgado ? n : 'Juzgado de Policía Local $n');
  }
}
