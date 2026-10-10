import 'package:flutter/material.dart';

import '../ley/ley.dart';
import '../ley/multas.dart';
import 'app_scope.dart';
import 'ley.dart';

Color colorGravedad(Gravedad g, ColorScheme c) => switch (g) {
      Gravedad.gravisima => c.error,
      Gravedad.grave => Colors.deepOrange.shade700,
      Gravedad.menosGrave => Colors.amber.shade800,
      Gravedad.leve => Colors.green.shade700,
    };

class EtiquetaGravedad extends StatelessWidget {
  const EtiquetaGravedad(this.gravedad, {super.key});
  final Gravedad gravedad;

  @override
  Widget build(BuildContext context) {
    final color = colorGravedad(gravedad, Theme.of(context).colorScheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(gravedad.nombre,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}

/// Tabla de infracciones y multas. Con [seleccionar] = true, al elegir una
/// infracción se devuelve con Navigator.pop (para el registro de controles).
class TablaMultasPantalla extends StatefulWidget {
  const TablaMultasPantalla({super.key, this.seleccionar = false});
  final bool seleccionar;

  @override
  State<TablaMultasPantalla> createState() => _TablaMultasPantallaState();
}

class _TablaMultasPantallaState extends State<TablaMultasPantalla> {
  String _consulta = '';
  Gravedad? _filtro;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final tabla = scope.ley?.multas;
    if (tabla == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tabla de multas')),
        body: const Center(child: Text('Tabla no disponible en esta versión.')),
      );
    }
    final resultados = tabla
        .buscar(_consulta)
        .where((i) => _filtro == null || i.gravedad == _filtro)
        .toList();
    final mostrarResumen = _consulta.isEmpty && _filtro == null && !widget.seleccionar;

    return Scaffold(
      appBar: AppBar(
          title: Text(widget.seleccionar ? 'Elegir infracción' : 'Tabla de multas')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Buscar: "celular", "luz roja", "200 5"…',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (s) => setState(() => _consulta = s),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            for (final g in Gravedad.values.where((g) => g != Gravedad.leve))
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(g.nombre),
                  selected: _filtro == g,
                  onSelected: (s) => setState(() => _filtro = s ? g : null),
                ),
              ),
          ]),
        ),
        Expanded(
          child: ListView(children: [
            if (mostrarResumen) _Escala(tabla: tabla, utm: scope.utm),
            for (final i in resultados)
              ListTile(
                title: Row(children: [
                  Text(i.referencia, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  EtiquetaGravedad(i.gravedad),
                ]),
                subtitle: Text(i.texto, maxLines: 3, overflow: TextOverflow.ellipsis),
                onTap: () => widget.seleccionar
                    ? Navigator.pop(context, i)
                    : _detalle(context, i, tabla, scope),
              ),
            if (resultados.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Text('Sin resultados. Si no aparece en la lista, puede ser '
                    'una infracción leve (art. 202).', textAlign: TextAlign.center),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(avisoLegal, style: Theme.of(context).textTheme.bodySmall),
            ),
          ]),
        ),
      ]),
    );
  }

  void _detalle(BuildContext context, Infraccion i, TablaMultas tabla, AppScope scope) {
    final rango = tabla.escala[i.gravedad]!;
    final utm = scope.utm;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (ctx, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Row(children: [
              Text(i.referencia, style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(width: 8),
              EtiquetaGravedad(i.gravedad),
            ]),
            const SizedBox(height: 12),
            Text(i.texto, style: Theme.of(ctx).textTheme.bodyLarge),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.payments_outlined),
                title: Text('Multa: ${formatoUtm(rango.min)} a ${formatoUtm(rango.max)}'),
                subtitle: Text(utm == null
                    ? 'Escala del art. 204'
                    : '${utm.rango(rango)} (UTM ${utm.mes}). Escala del art. 204'),
              ),
            ),
            for (final numero in [i.articulo, '204', '207'])
              if (scope.ley!.articulo(numero) case final a?)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.gavel),
                  title: Text('Ver artículo $numero'),
                  subtitle: Text(switch (numero) {
                    '204' => 'Escala de multas, reincidencia y rebaja',
                    '207' => 'Suspensión de licencia',
                    _ => i.gravedad.nombre,
                  }),
                  onTap: () => Navigator.push(ctx,
                      MaterialPageRoute(builder: (_) => ArticuloPantalla(articulo: a))),
                ),
          ],
        ),
      ),
    );
  }
}

/// Escala del art. 204 y reglas del mismo artículo citadas textualmente.
class _Escala extends StatelessWidget {
  const _Escala({required this.tabla, required this.utm});
  final TablaMultas tabla;
  final Utm? utm;

  @override
  Widget build(BuildContext context) {
    final ley = AppScope.of(context).ley!;
    final art204 = ley.articulo('204')?.texto.split('\n\n') ?? const <String>[];
    String? cita(String clave) =>
        art204.where((p) => normalizarTexto(p).contains(clave)).firstOrNull;
    final reglas = [
      cita('reincidentes'),
      cita('dos o mas infracciones'),
      cita('casos calificados'),
      ley.articulo('205')?.texto,
    ].whereType<String>();

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Escala de multas (art. 204)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final g in Gravedad.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                SizedBox(width: 110, child: EtiquetaGravedad(g)),
                Expanded(
                  child: Text(
                    '${formatoUtm(tabla.escala[g]!.min)} a ${formatoUtm(tabla.escala[g]!.max)}'
                    '${utm == null ? '' : '\n${utm!.rango(tabla.escala[g]!)}'}',
                  ),
                ),
              ]),
            ),
          if (utm != null)
            Text('Valor UTM ${utm!.mes}: ${utm!.pesos(1)} (${utm!.fuente}).',
                style: Theme.of(context).textTheme.bodySmall),
          const Text(
              'Leves (art. 202): todas las infracciones que no están en los arts. 199 a 201.'),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Reglas importantes (texto de la ley)'),
            children: [
              for (final r in reglas)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('«$r»'),
                ),
            ],
          ),
        ]),
      ),
    );
  }
}
