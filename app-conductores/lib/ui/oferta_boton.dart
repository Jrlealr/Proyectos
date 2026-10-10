import 'package:flutter/material.dart';

import '../guantera/modelos.dart';
import '../ofertas/motor_ofertas.dart';
import '../ofertas/oferta.dart';
import 'app_scope.dart';

/// Punto de oferta opcional. En v1 no muestra nada (flags desactivados).
/// Ver docs/puntos-de-oferta.md.
class OfertaBoton extends StatelessWidget {
  const OfertaBoton({
    super.key,
    required this.contexto,
    required this.ciclo,
  });

  final ContextoOferta contexto;

  /// Identifica el ciclo (ej. documento + vencimiento) para que una oferta
  /// descartada no reaparezca en ese mismo ciclo.
  final String ciclo;

  static ContextoOferta contextoVencimiento(Documento d, DateTime hoy) =>
      ContextoOferta(
        ubicacion: 'alerta_vencimiento',
        documento: d.tipo.clave,
        diasParaVencer: diasParaVencer(d, hoy),
      );

  static String cicloDe(Documento d) =>
      '${d.id}:${d.vencimiento?.toIso8601String() ?? '-'}';

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final guantera = scope.notifier!;
    final descartadas = guantera.ofertasDescartadas
        .where((k) => k.endsWith('@$ciclo'))
        .map((k) => k.substring(0, k.indexOf('@')))
        .toSet();
    final oferta = scope.ofertas.ofertaPara(
      contexto,
      usuarioPermiteOfertas: guantera.permiteOfertas,
      descartadas: descartadas,
    );
    if (oferta == null) return const SizedBox.shrink();

    return Card(
      child: ListTile(
        leading: const Icon(Icons.local_offer_outlined),
        title: Text(oferta.texto),
        subtitle: Text(scope.ofertas.config.etiqueta),
        onTap: () => _consentir(context, oferta),
        trailing: IconButton(
          tooltip: 'No mostrar',
          icon: const Icon(Icons.close),
          onPressed: () => guantera.descartarOferta('${oferta.id}@$ciclo'),
        ),
      ),
    );
  }

  Future<void> _consentir(BuildContext context, Oferta oferta) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(oferta.texto),
        content: Text(
          'Para continuar se compartirá solo lo siguiente con el proveedor:\n\n'
          '• ${oferta.datosCompartidos.join('\n• ')}\n\n'
          'Puedes desactivar las ofertas en Ajustes.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Aceptar')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    // TODO: abrir oferta.urlDestino cuando exista un convenio activo.
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Oferta aún no disponible')));
  }
}
