import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdfrx/pdfrx.dart';

import '../guantera/modelos.dart';
import 'app_scope.dart';
import 'estado.dart';
import 'oferta_boton.dart';

class DocumentoTile extends StatelessWidget {
  const DocumentoTile(this.doc, {super.key, this.mostrarVehiculo = false});
  final Documento doc;
  final bool mostrarVehiculo;

  @override
  Widget build(BuildContext context) {
    final guantera = AppScope.guantera(context);
    final hoy = guantera.hoy;
    final patente = guantera.vehiculo(doc.vehiculoId)?.patente;
    return ListTile(
      leading: EstadoIcono(estadoDe(doc, hoy)),
      title: Text(mostrarVehiculo && patente != null
          ? '${doc.tipo.nombre} · $patente'
          : doc.tipo.nombre),
      subtitle: Text(textoEstado(doc, hoy)),
      trailing: Icon(doc.esPdf ? Icons.picture_as_pdf : Icons.image_outlined),
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => DocumentoVisor(doc: doc))),
    );
  }
}

/// Formulario para agregar un documento (de un vehículo o personal).
class DocumentoForm extends StatefulWidget {
  const DocumentoForm({super.key, this.vehiculoId});

  /// null = documento personal.
  final String? vehiculoId;

  @override
  State<DocumentoForm> createState() => _DocumentoFormState();
}

class _DocumentoFormState extends State<DocumentoForm> {
  late final List<TipoDocumento> _tipos = TipoDocumento.values
      .where((t) => t.personal == (widget.vehiculoId == null))
      .toList();
  late TipoDocumento _tipo = _tipos.first;
  Uint8List? _bytes;
  bool _esPdf = false;
  String _nombre = '';
  DateTime? _vencimiento;
  final _nota = TextEditingController();
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _sugerirFecha();
  }

  @override
  void dispose() {
    _nota.dispose();
    super.dispose();
  }

  void _sugerirFecha() =>
      _vencimiento = vencimientoSugerido(_tipo, DateTime.now());

  Future<void> _elegirArchivo() async {
    final f = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'heic', 'webp'],
    );
    if (f == null) return;
    final bytes = await f.xFile.readAsBytes();
    setState(() {
      _bytes = bytes;
      _esPdf = f.extension?.toLowerCase() == 'pdf';
      _nombre = f.name;
    });
  }

  Future<void> _tomarFoto(ImageSource fuente) async {
    final foto = await ImagePicker()
        .pickImage(source: fuente, imageQuality: 85, maxWidth: 2400);
    if (foto == null) return;
    final bytes = await foto.readAsBytes();
    setState(() {
      _bytes = bytes;
      _esPdf = false;
      _nombre = foto.name;
    });
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final f = await showDatePicker(
      context: context,
      initialDate: _vencimiento ?? hoy,
      firstDate: DateTime(hoy.year - 5),
      lastDate: DateTime(hoy.year + 15),
      helpText: 'Fecha de vencimiento',
    );
    if (f != null) setState(() => _vencimiento = f);
  }

  Future<void> _guardar() async {
    if (_bytes == null) return;
    setState(() => _guardando = true);
    await AppScope.guantera(context).agregarDocumento(
      tipo: _tipo,
      vehiculoId: widget.vehiculoId,
      bytes: _bytes!,
      esPdf: _esPdf,
      nombreArchivo: _nombre,
      vencimiento: _vencimiento,
      nota: _nota.text,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final aviso = _tipo.avisoValidez;
    return Scaffold(
      appBar: AppBar(title: const Text('Agregar documento')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<TipoDocumento>(
            initialValue: _tipo,
            decoration: const InputDecoration(labelText: 'Tipo de documento'),
            items: [
              for (final t in _tipos)
                DropdownMenuItem(value: t, child: Text(t.nombre)),
            ],
            onChanged: (t) => setState(() {
              _tipo = t!;
              _sugerirFecha();
            }),
          ),
          if (aviso != null) ...[
            const SizedBox(height: 12),
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  const Icon(Icons.info_outline),
                  const SizedBox(width: 12),
                  Expanded(child: Text(aviso)),
                ]),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
              onPressed: _elegirArchivo,
              icon: const Icon(Icons.upload_file),
              label: const Text('PDF o imagen'),
            ),
            OutlinedButton.icon(
              onPressed: () => _tomarFoto(ImageSource.camera),
              icon: const Icon(Icons.photo_camera),
              label: const Text('Cámara'),
            ),
            OutlinedButton.icon(
              onPressed: () => _tomarFoto(ImageSource.gallery),
              icon: const Icon(Icons.photo_library),
              label: const Text('Galería'),
            ),
          ]),
          if (_bytes != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(_esPdf ? Icons.picture_as_pdf : Icons.image),
              title: Text(_nombre, overflow: TextOverflow.ellipsis),
            ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: Text(_vencimiento == null
                ? 'Sin fecha de vencimiento'
                : 'Vence el ${formatoFecha.format(_vencimiento!)}'),
            subtitle: _tipo.vence
                ? const Text('Revisa la fecha impresa en el documento')
                : null,
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              if (_vencimiento != null)
                IconButton(
                  tooltip: 'Quitar fecha',
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() => _vencimiento = null),
                ),
              IconButton(
                tooltip: 'Elegir fecha',
                icon: const Icon(Icons.edit_calendar),
                onPressed: _elegirFecha,
              ),
            ]),
          ),
          TextField(
            controller: _nota,
            decoration: const InputDecoration(labelText: 'Nota (opcional)'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _bytes == null || _guardando ? null : _guardar,
            child: Text(_guardando ? 'Guardando…' : 'Guardar'),
          ),
        ],
      ),
    );
  }
}

/// Muestra un documento descifrado en memoria (nunca se escribe en claro).
class DocumentoVisor extends StatefulWidget {
  const DocumentoVisor({super.key, required this.doc});
  final Documento doc;

  @override
  State<DocumentoVisor> createState() => _DocumentoVisorState();
}

class _DocumentoVisorState extends State<DocumentoVisor> {
  late Documento _doc = widget.doc;
  late final Future<Uint8List> _bytes =
      AppScope.guantera(context).leerArchivo(_doc);

  Future<void> _editarFecha() async {
    final hoy = DateTime.now();
    final f = await showDatePicker(
      context: context,
      initialDate: _doc.vencimiento ?? hoy,
      firstDate: DateTime(hoy.year - 5),
      lastDate: DateTime(hoy.year + 15),
      helpText: 'Nueva fecha de vencimiento',
    );
    if (f == null || !mounted) return;
    final guantera = AppScope.guantera(context);
    await guantera.actualizarVencimiento(_doc, f);
    setState(() => _doc = guantera
        .documentosDe(_doc.vehiculoId)
        .firstWhere((d) => d.id == _doc.id));
  }

  Future<void> _borrar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar documento?'),
        content: const Text('Se borrará de este teléfono.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await AppScope.guantera(context).borrarDocumento(_doc);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final hoy = AppScope.guantera(context).hoy;
    return Scaffold(
      appBar: AppBar(
        title: Text(_doc.tipo.nombre),
        actions: [
          IconButton(
              tooltip: 'Cambiar vencimiento',
              icon: const Icon(Icons.edit_calendar),
              onPressed: _editarFecha),
          IconButton(
              tooltip: 'Eliminar',
              icon: const Icon(Icons.delete_outline),
              onPressed: _borrar),
        ],
      ),
      body: Column(children: [
        ListTile(
          leading: EstadoIcono(estadoDe(_doc, hoy)),
          title: Text(textoEstado(_doc, hoy)),
          subtitle: _doc.nota.isEmpty ? null : Text(_doc.nota),
        ),
        OfertaBoton(
          contexto: OfertaBoton.contextoVencimiento(_doc, hoy),
          ciclo: OfertaBoton.cicloDe(_doc),
        ),
        Expanded(
          child: FutureBuilder<Uint8List>(
            future: _bytes,
            builder: (context, snap) {
              if (snap.hasError) {
                return const Center(child: Text('No se pudo abrir el documento'));
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return _doc.esPdf
                  ? PdfViewer.data(snap.data!, sourceName: _doc.id)
                  : InteractiveViewer(
                      maxScale: 6,
                      child: Center(child: Image.memory(snap.data!)),
                    );
            },
          ),
        ),
      ]),
    );
  }
}
