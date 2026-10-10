import 'package:flutter/material.dart';

import '../guantera/modelos.dart';
import '../ley/ley.dart';
import 'app_scope.dart';
import 'multas.dart';

const avisoLegal =
    'Texto oficial obtenido de LeyChile (Biblioteca del Congreso Nacional). '
    'Información referencial: no constituye asesoría legal.';

/// Pestaña "Ley": buscador + temas. Los temas se ordenan según los
/// vehículos del usuario (si tiene moto, "Motocicletas" va primero).
class LeyPantalla extends StatefulWidget {
  const LeyPantalla({super.key});

  @override
  State<LeyPantalla> createState() => _LeyPantallaState();
}

class _LeyPantallaState extends State<LeyPantalla> {
  final _consulta = TextEditingController();
  String _texto = '';

  @override
  void dispose() {
    _consulta.dispose();
    super.dispose();
  }

  List<TemaLey> _temas(BuildContext context) {
    final tieneMoto = AppScope.guantera(context)
        .vehiculos
        .any((v) => v.tipo == TipoVehiculo.moto);
    final temas = [...TemaLey.values];
    if (tieneMoto) {
      temas
        ..remove(TemaLey.motos)
        ..insert(1, TemaLey.motos);
    }
    return temas;
  }

  @override
  Widget build(BuildContext context) {
    final ley = AppScope.of(context).ley;
    if (ley == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('El texto de la ley aún no está disponible en esta versión.',
              textAlign: TextAlign.center),
        ),
      );
    }
    final resultados = ley.buscar(_texto);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: TextField(
          controller: _consulta,
          decoration: InputDecoration(
            hintText: 'Buscar: "casco", "art 96", "alcohol"…',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _texto.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() {
                      _consulta.clear();
                      _texto = '';
                    }),
                  ),
            border: const OutlineInputBorder(),
          ),
          onChanged: (s) => setState(() => _texto = s),
        ),
      ),
      Expanded(
        child: _texto.trim().isNotEmpty
            ? ListaArticulos(
                articulos: resultados,
                resaltar: _texto,
                vacio: 'Sin resultados para "$_texto"',
              )
            : ListView(children: [
                if (ley.multas != null)
                  ListTile(
                    leading: const Icon(Icons.payments_outlined),
                    title: const Text('Tabla de multas'),
                    subtitle: const Text('Infracciones por gravedad y montos'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const TablaMultasPantalla())),
                  ),
                for (final t in _temas(context))
                  ListTile(
                    leading: Icon(_icono(t)),
                    title: Text(t.nombre),
                    trailing: Text('${ley.deTema(t).length}'),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => TemaPantalla(tema: t))),
                  ),
                ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: const Text('Ley completa'),
                  trailing: Text('${ley.articulos.length}'),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => Scaffold(
                                appBar: AppBar(title: Text(ley.titulo)),
                                body: ListaArticulos(articulos: ley.articulos),
                              ))),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '${ley.norma}\n'
                    '${ley.versionFecha.isEmpty ? '' : 'Versión: ${ley.versionFecha}\n'}'
                    '$avisoLegal',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ]),
      ),
    ]);
  }

  IconData _icono(TemaLey t) => switch (t) {
        TemaLey.documentos => Icons.folder_shared_outlined,
        TemaLey.fiscalizacion => Icons.local_police_outlined,
        TemaLey.infracciones => Icons.gavel,
        TemaLey.velocidad => Icons.speed,
        TemaLey.alcohol => Icons.no_drinks_outlined,
        TemaLey.celular => Icons.phone_disabled_outlined,
        TemaLey.motos => Icons.two_wheeler,
        TemaLey.licencias => Icons.badge_outlined,
      };
}

class TemaPantalla extends StatelessWidget {
  const TemaPantalla({super.key, required this.tema});
  final TemaLey tema;

  @override
  Widget build(BuildContext context) {
    final ley = AppScope.of(context).ley!;
    return Scaffold(
      appBar: AppBar(title: Text(tema.nombre)),
      body: Column(children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            'Artículos que mencionan este tema (selección automática por '
            'palabras clave; revisa el texto completo de cada uno).',
          ),
        ),
        Expanded(child: ListaArticulos(articulos: ley.deTema(tema))),
      ]),
    );
  }
}

class ListaArticulos extends StatelessWidget {
  const ListaArticulos({
    super.key,
    required this.articulos,
    this.resaltar = '',
    this.vacio = 'No hay artículos',
  });

  final List<Articulo> articulos;
  final String resaltar;
  final String vacio;

  @override
  Widget build(BuildContext context) {
    if (articulos.isEmpty) return Center(child: Text(vacio));
    return ListView.separated(
      itemCount: articulos.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final a = articulos[i];
        return ListTile(
          title: Text('Artículo ${a.numero}'),
          subtitle: Text(
            a.texto,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => ArticuloPantalla(articulo: a, resaltar: resaltar))),
        );
      },
    );
  }
}

class ArticuloPantalla extends StatelessWidget {
  const ArticuloPantalla({super.key, required this.articulo, this.resaltar = ''});
  final Articulo articulo;
  final String resaltar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Artículo ${articulo.numero}')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (articulo.ubicacion.isNotEmpty)
          Text(articulo.ubicacion, style: tema.textTheme.labelLarge),
        const SizedBox(height: 12),
        SelectableText.rich(
          TextSpan(
            style: tema.textTheme.bodyLarge,
            children: resaltarTexto(articulo.texto, resaltar,
                tema.colorScheme.tertiaryContainer),
          ),
        ),
        const SizedBox(height: 24),
        Text(avisoLegal, style: tema.textTheme.bodySmall),
      ]),
    );
  }
}

/// Divide [texto] resaltando las palabras de [consulta] (sin tildes).
List<TextSpan> resaltarTexto(String texto, String consulta, Color fondo) {
  final palabras = normalizarTexto(consulta)
      .split(' ')
      .where((p) => p.length >= 3)
      .toList();
  if (palabras.isEmpty) return [TextSpan(text: texto)];
  // normalizarTexto conserva la longitud carácter a carácter salvo espacios;
  // aquí se normaliza sin colapsar espacios para mantener posiciones.
  final base = texto.toLowerCase().split('').map((c) => normalizarTexto(c).isEmpty ? c : normalizarTexto(c)).join();
  final marcas = List<bool>.filled(texto.length, false);
  for (final p in palabras) {
    var i = base.indexOf(p);
    while (i >= 0) {
      for (var k = i; k < i + p.length && k < marcas.length; k++) {
        marcas[k] = true;
      }
      i = base.indexOf(p, i + p.length);
    }
  }
  final spans = <TextSpan>[];
  var inicio = 0;
  for (var i = 1; i <= texto.length; i++) {
    if (i == texto.length || marcas[i] != marcas[inicio]) {
      spans.add(TextSpan(
        text: texto.substring(inicio, i),
        style: marcas[inicio] ? TextStyle(backgroundColor: fondo) : null,
      ));
      inicio = i;
    }
  }
  return spans;
}
