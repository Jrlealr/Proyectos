import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../guantera/fiscalizacion.dart';
import '../guantera/modelos.dart';
import 'app_scope.dart';
import 'archivos.dart';
import 'controles.dart';
import 'estado.dart';
import 'ley.dart';

/// Abre el Modo Fiscalización. Si hay varios vehículos, pregunta cuál.
Future<void> abrirFiscalizacion(BuildContext context) async {
  final vehiculos = AppScope.guantera(context).vehiculos;
  String? vehiculoId;
  if (vehiculos.length == 1) {
    vehiculoId = vehiculos.single.id;
  } else if (vehiculos.length > 1) {
    vehiculoId = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const ListTile(title: Text('¿Qué vehículo estás conduciendo?')),
          for (final v in vehiculos)
            ListTile(
              leading: Icon(v.tipo == TipoVehiculo.moto
                  ? Icons.two_wheeler
                  : Icons.directions_car),
              title: Text(v.patente),
              subtitle: v.descripcion.isEmpty ? null : Text(v.descripcion),
              onTap: () => Navigator.pop(ctx, v.id),
            ),
        ]),
      ),
    );
    if (vehiculoId == null) return;
  }
  if (!context.mounted) return;
  await Navigator.push(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => ModoFiscalizacion(vehiculoId: vehiculoId),
    ),
  );
}

/// Ajustes de pantalla durante la fiscalización. Los errores se ignoran
/// (ej. en pruebas o equipos sin soporte): nunca deben bloquear la vista.
class _Pantalla {
  static Future<void> _seguro(Future<void> Function() f) async {
    try {
      await f();
    } catch (_) {}
  }

  static Future<void> activar() async {
    await _seguro(() => SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky));
    await _seguro(() => ScreenBrightness.instance.setApplicationScreenBrightness(1.0));
    await _seguro(WakelockPlus.enable);
  }

  static Future<void> restaurar() async {
    await _seguro(() => SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    await _seguro(ScreenBrightness.instance.resetApplicationScreenBrightness);
    await _seguro(WakelockPlus.disable);
  }
}

class ModoFiscalizacion extends StatefulWidget {
  const ModoFiscalizacion({super.key, this.vehiculoId});
  final String? vehiculoId;

  @override
  State<ModoFiscalizacion> createState() => _ModoFiscalizacionState();
}

class _ModoFiscalizacionState extends State<ModoFiscalizacion> {
  final _paginas = PageController();
  int _pagina = 0;

  @override
  void initState() {
    super.initState();
    _Pantalla.activar();
  }

  @override
  void dispose() {
    _Pantalla.restaurar();
    _paginas.dispose();
    super.dispose();
  }

  void _ir(int i) => _paginas.animateToPage(i,
      duration: const Duration(milliseconds: 250), curve: Curves.easeOut);

  @override
  Widget build(BuildContext context) {
    final guantera = AppScope.guantera(context);
    final vehiculo = guantera.vehiculo(widget.vehiculoId);
    final items = itemsFiscalizacion(guantera, widget.vehiculoId);
    final guardados = items.where((i) => i.documento != null).toList();
    final titulos = [
      'Resumen',
      for (final i in guardados) i.tipo.nombre,
      'Si no aceptan tus documentos',
    ];

    return Scaffold(
      appBar: AppBar(
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ControlForm(vehiculoId: widget.vehiculoId))),
            icon: const Icon(Icons.edit_note),
            label: const Text('Registrar'),
          ),
        ],
        title: Text(vehiculo?.patente ?? 'Fiscalización',
            style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('${titulos[_pagina]} · ${_pagina + 1}/${titulos.length}'),
          ),
        ),
      ),
      body: PageView(
        controller: _paginas,
        onPageChanged: (i) => setState(() => _pagina = i),
        children: [
          _Resumen(
            items: items,
            hoy: guantera.hoy,
            alTocar: (item) {
              final i = guardados.indexOf(item);
              if (i >= 0) _ir(i + 1);
            },
          ),
          for (final i in guardados) _PaginaDocumento(i.documento!, guantera.hoy),
          const _SiNoAceptan(),
        ],
      ),
    );
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({required this.items, required this.hoy, required this.alTocar});
  final List<ItemFiscalizacion> items;
  final DateTime hoy;
  final void Function(ItemFiscalizacion) alTocar;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    return ListView(padding: const EdgeInsets.symmetric(vertical: 8), children: [
      for (final i in items)
        ListTile(
          leading: i.documento == null
              ? Icon(Icons.cancel_outlined, color: colores.outline)
              : EstadoIcono(estadoDe(i.documento!, hoy)),
          title: Text(i.tipo.nombre, style: const TextStyle(fontSize: 18)),
          subtitle: Text(i.documento == null
              ? (i.tipo == TipoDocumento.licencia
                  ? 'No guardada. Si tienes licencia digital, muéstrala desde la app de Conaset.'
                  : 'No guardado en la app')
              : textoEstado(i.documento!, hoy)),
          trailing: i.documento == null ? null : const Icon(Icons.chevron_right),
          onTap: i.documento == null ? null : () => alTocar(i),
        ),
      const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Desliza hacia el lado para ver cada documento.',
            textAlign: TextAlign.center),
      ),
    ]);
  }
}

class _PaginaDocumento extends StatefulWidget {
  const _PaginaDocumento(this.doc, this.hoy);
  final Documento doc;
  final DateTime hoy;

  @override
  State<_PaginaDocumento> createState() => _PaginaDocumentoState();
}

class _PaginaDocumentoState extends State<_PaginaDocumento>
    with AutomaticKeepAliveClientMixin {
  late final Future<Uint8List> _bytes =
      AppScope.guantera(context).leerArchivo(widget.doc);

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final estado = estadoDe(widget.doc, widget.hoy);
    final color = colorEstado(estado, Theme.of(context).colorScheme);
    return Column(children: [
      Container(
        width: double.infinity,
        color: color.withValues(alpha: 0.12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          EstadoIcono(estado),
          const SizedBox(width: 12),
          Expanded(
            child: Text(textoEstado(widget.doc, widget.hoy),
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ]),
      ),
      Expanded(
        child: ColoredBox(
          // Fondo blanco: mejora la lectura del código QR.
          color: Colors.white,
          child: VistaArchivo(
              bytes: _bytes, esPdf: widget.doc.esPdf, nombre: 'fisc-${widget.doc.id}'),
        ),
      ),
    ]);
  }
}

/// Orientación práctica. El detalle legal (artículos y normas aplicables)
/// se agregará con el módulo de Ley de Tránsito, validado por un abogado.
class _SiNoAceptan extends StatelessWidget {
  const _SiNoAceptan();

  @override
  Widget build(BuildContext context) {
    const pasos = [
      'Mantén la calma y muestra el código QR del documento: permite verificar que es original y está vigente.',
      'Pide amablemente que se verifique el QR o se consulte en línea.',
      'Anota la fecha, hora, lugar y el nombre y grado del funcionario.',
      'Si te cursan una infracción, puedes presentar tus descargos ante el Juzgado de Policía Local indicado en la citación, acompañando los documentos digitales vigentes.',
    ];
    return ListView(padding: const EdgeInsets.all(16), children: [
      for (final (i, p) in pasos.indexed)
        ListTile(
          leading: CircleAvatar(child: Text('${i + 1}')),
          title: Text(p),
        ),
      const _ArticulosDocumentos(),
      const SizedBox(height: 16),
      Text(
        'Información referencial, no constituye asesoría legal.',
        style: Theme.of(context).textTheme.bodySmall,
        textAlign: TextAlign.center,
      ),
    ]);
  }
}

/// Artículos de la Ley 18.290 sobre los documentos que se deben portar.
/// Nota: la ley no regula el formato digital; eso depende de otras normas.
class _ArticulosDocumentos extends StatelessWidget {
  const _ArticulosDocumentos();

  static const _articulos = {
    '5': 'Licencia para conducir',
    '6': 'Llevar licencia y certificado del SOAP',
    '51': 'Placa patente, permiso de circulación y SOAP',
    '89': 'Revisión técnica vigente',
  };

  @override
  Widget build(BuildContext context) {
    final ley = AppScope.of(context).ley;
    if (ley == null) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text('Lo que exige la Ley de Tránsito',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      for (final MapEntry(key: numero, value: resumen) in _articulos.entries)
        if (ley.articulo(numero) case final a?)
          ListTile(
            leading: const Icon(Icons.gavel),
            title: Text('Artículo $numero'),
            subtitle: Text(resumen),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => ArticuloPantalla(articulo: a))),
          ),
    ]);
  }
}
