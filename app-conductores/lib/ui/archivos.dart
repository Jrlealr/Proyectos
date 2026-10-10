import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdfrx/pdfrx.dart';

typedef ArchivoElegido = ({Uint8List bytes, bool esPdf, String nombre});

Future<ArchivoElegido?> elegirArchivo() async {
  final f = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'heic', 'webp'],
  );
  if (f == null) return null;
  return (
    bytes: await f.xFile.readAsBytes(),
    esPdf: f.extension?.toLowerCase() == 'pdf',
    nombre: f.name,
  );
}

Future<ArchivoElegido?> tomarFoto(ImageSource fuente) async {
  final foto = await ImagePicker()
      .pickImage(source: fuente, imageQuality: 85, maxWidth: 2400);
  if (foto == null) return null;
  return (bytes: await foto.readAsBytes(), esPdf: false, nombre: foto.name);
}

/// Botones "PDF o imagen", "Cámara" y "Galería".
class BotonesArchivo extends StatelessWidget {
  const BotonesArchivo({super.key, required this.alElegir});
  final void Function(ArchivoElegido) alElegir;

  Future<void> _usar(Future<ArchivoElegido?> f) async {
    final a = await f;
    if (a != null) alElegir(a);
  }

  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 8, children: [
        OutlinedButton.icon(
          onPressed: () => _usar(elegirArchivo()),
          icon: const Icon(Icons.upload_file),
          label: const Text('PDF o imagen'),
        ),
        OutlinedButton.icon(
          onPressed: () => _usar(tomarFoto(ImageSource.camera)),
          icon: const Icon(Icons.photo_camera),
          label: const Text('Cámara'),
        ),
        OutlinedButton.icon(
          onPressed: () => _usar(tomarFoto(ImageSource.gallery)),
          icon: const Icon(Icons.photo_library),
          label: const Text('Galería'),
        ),
      ]);
}

/// Muestra un archivo descifrado en memoria (PDF o imagen).
class VistaArchivo extends StatelessWidget {
  const VistaArchivo({
    super.key,
    required this.bytes,
    required this.esPdf,
    required this.nombre,
  });

  final Future<Uint8List> bytes;
  final bool esPdf;

  /// Identificador único para el visor de PDF.
  final String nombre;

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
        future: bytes,
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('No se pudo abrir el archivo'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return esPdf
              ? PdfViewer.data(snap.data!, sourceName: nombre)
              : InteractiveViewer(
                  maxScale: 6,
                  child: Center(child: Image.memory(snap.data!)),
                );
        },
      );
}
