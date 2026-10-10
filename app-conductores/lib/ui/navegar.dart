import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../navegacion/navegacion.dart';
import 'app_scope.dart';

/// Abre [destino] en la app de navegación preferida (o pregunta cuál).
Future<void> navegar(BuildContext context, Destino destino) async {
  var app = AppScope.guantera(context).appNavegacion;
  if (app == AppNavegacion.preguntar) {
    final elegida = await showModalBottomSheet<AppNavegacion>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const ListTile(title: Text('Abrir con')),
          for (final a in [AppNavegacion.googleMaps, AppNavegacion.waze])
            ListTile(
              leading: Icon(a == AppNavegacion.waze ? Icons.navigation : Icons.map),
              title: Text(a.nombre),
              onTap: () => Navigator.pop(ctx, a),
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text('Puedes elegir una app fija en Ajustes.'),
          ),
        ]),
      ),
    );
    if (elegida == null) return;
    app = elegida;
  }
  final ok = await launchUrl(uriNavegacion(app, destino),
      mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir ${app.nombre}')));
  }
}

/// Fila "Cómo llegar" con ícono de mapa.
class BotonNavegar extends StatelessWidget {
  const BotonNavegar({
    super.key,
    required this.titulo,
    required this.destino,
    this.subtitulo,
  });

  final String titulo;
  final String? subtitulo;
  final Destino destino;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.directions),
        title: Text(titulo),
        subtitle: subtitulo == null ? null : Text(subtitulo!),
        trailing: const Icon(Icons.open_in_new, size: 18),
        onTap: () => navegar(context, destino),
      );
}
