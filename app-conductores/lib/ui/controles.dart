import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../guantera/control.dart';
import '../ofertas/motor_ofertas.dart';
import 'app_scope.dart';
import 'archivos.dart';
import 'oferta_boton.dart';
import 'vehiculos.dart' show Vacio;

final _fechaHoraFmt = DateFormat('dd-MM-yyyy HH:mm');

class ControlesPantalla extends StatelessWidget {
  const ControlesPantalla({super.key});

  @override
  Widget build(BuildContext context) {
    final controles = AppScope.guantera(context).controles;
    if (controles.isEmpty) {
      return const Vacio(
        icono: Icons.local_police_outlined,
        texto: 'Registra cada control: fecha, lugar, funcionario y resultado. '
            'Te servirá si necesitas presentar descargos.',
      );
    }
    return ListView(children: [
      for (final c in controles)
        ListTile(
          leading: Icon(c.resultado.conCitacion ? Icons.gavel : Icons.check_circle_outline),
          title: Text('${_fechaHoraFmt.format(c.fechaHora)}'
              '${c.patente.isEmpty ? '' : ' · ${c.patente}'}'),
          subtitle: Text([
            c.resultado.nombre,
            if (c.lugar.isNotEmpty) c.lugar,
          ].join(' · ')),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => ControlDetalle(controlId: c.id))),
        ),
    ]);
  }
}

class ControlDetalle extends StatelessWidget {
  const ControlDetalle({super.key, required this.controlId});
  final String controlId;

  Future<void> _borrar(BuildContext context, Control c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar registro?'),
        content: const Text('Se borrarán también sus fotos y archivos.'),
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
    if (ok != true || !context.mounted) return;
    Navigator.pop(context);
    await AppScope.guantera(context).borrarControl(c);
  }

  @override
  Widget build(BuildContext context) {
    final guantera = AppScope.guantera(context);
    final c = guantera.control(controlId);
    if (c == null) return const Scaffold();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Control'),
        actions: [
          IconButton(
            tooltip: 'Copiar resumen',
            icon: const Icon(Icons.copy),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: resumenControl(c)));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Resumen copiado')));
              }
            },
          ),
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => ControlForm(control: c))),
          ),
          IconButton(
            tooltip: 'Eliminar',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _borrar(context, c),
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        SelectableText(resumenControl(c)),
        if (c.resultado.conCitacion)
          OfertaBoton(
            contexto: const ContextoOferta(
                ubicacion: 'registro_parte', parteRegistrado: true),
            ciclo: 'control:${c.id}',
          ),
        if (c.adjuntos.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Adjuntos', style: Theme.of(context).textTheme.titleMedium),
          for (final a in c.adjuntos)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(a.esPdf ? Icons.picture_as_pdf : Icons.image_outlined),
              title: Text(a.nombre, overflow: TextOverflow.ellipsis),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: Text(a.nombre)),
                    body: VistaArchivo(
                        bytes: guantera.leerAdjunto(a),
                        esPdf: a.esPdf,
                        nombre: a.archivoId),
                  ),
                ),
              ),
            ),
        ],
      ]),
    );
  }
}

class ControlForm extends StatefulWidget {
  const ControlForm({super.key, this.control, this.vehiculoId});

  /// null = nuevo registro.
  final Control? control;

  /// Vehículo preseleccionado (ej. desde el Modo Fiscalización).
  final String? vehiculoId;

  @override
  State<ControlForm> createState() => _ControlFormState();
}

class _ControlFormState extends State<ControlForm> {
  late final Control? _c = widget.control;
  late DateTime _fechaHora = _c?.fechaHora ?? DateTime.now();
  late String? _vehiculoId = _c?.vehiculoId ?? widget.vehiculoId;
  late Institucion _institucion = _c?.institucion ?? Institucion.carabineros;
  late ResultadoControl _resultado = _c?.resultado ?? ResultadoControl.sinInfraccion;
  late DateTime? _comparecencia = _c?.fechaComparecencia;
  late double? _lat = _c?.latitud;
  late double? _lng = _c?.longitud;
  late final List<Adjunto> _adjuntos = [...?_c?.adjuntos];
  final _nuevos = <ArchivoElegido>[];
  bool _ubicando = false;
  bool _guardando = false;

  late final _lugar = TextEditingController(text: _c?.lugar);
  late final _nombre = TextEditingController(text: _c?.funcionarioNombre);
  late final _grado = TextEditingController(text: _c?.funcionarioGrado);
  late final _identificacion =
      TextEditingController(text: _c?.funcionarioIdentificacion);
  late final _motivo = TextEditingController(text: _c?.motivo);
  late final _citacion = TextEditingController(text: _c?.numeroCitacion);
  late final _juzgado = TextEditingController(text: _c?.juzgado);
  late final _infracciones = TextEditingController(text: _c?.infracciones);
  late final _notas = TextEditingController(text: _c?.notas);

  @override
  void dispose() {
    for (final t in [
      _lugar, _nombre, _grado, _identificacion, _motivo,
      _citacion, _juzgado, _infracciones, _notas,
    ]) {
      t.dispose();
    }
    super.dispose();
  }

  Future<DateTime?> _elegirFechaHora(DateTime inicial,
      {required DateTime desde, required DateTime hasta}) async {
    final d = await showDatePicker(
        context: context, initialDate: inicial, firstDate: desde, lastDate: hasta);
    if (d == null || !mounted) return null;
    final t = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(inicial));
    if (t == null) return null;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  Future<void> _ubicar() async {
    setState(() => _ubicando = true);
    String? error;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        error = 'Activa la ubicación del teléfono';
      } else {
        var permiso = await Geolocator.checkPermission();
        if (permiso == LocationPermission.denied) {
          permiso = await Geolocator.requestPermission();
        }
        if (permiso == LocationPermission.denied ||
            permiso == LocationPermission.deniedForever) {
          error = 'Sin permiso de ubicación';
        } else {
          final p = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)),
          );
          _lat = p.latitude;
          _lng = p.longitude;
        }
      }
    } catch (_) {
      error = 'No se pudo obtener la ubicación';
    }
    if (!mounted) return;
    setState(() => _ubicando = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    final guantera = AppScope.guantera(context);
    final control = Control(
      id: _c?.id ?? guantera.nuevoId(),
      fechaHora: _fechaHora,
      vehiculoId: _vehiculoId,
      patente: guantera.vehiculo(_vehiculoId)?.patente ?? _c?.patente ?? '',
      lugar: _lugar.text.trim(),
      latitud: _lat,
      longitud: _lng,
      institucion: _institucion,
      funcionarioNombre: _nombre.text.trim(),
      funcionarioGrado: _grado.text.trim(),
      funcionarioIdentificacion: _identificacion.text.trim(),
      motivo: _motivo.text.trim(),
      resultado: _resultado,
      numeroCitacion: _resultado.conCitacion ? _citacion.text.trim() : '',
      juzgado: _resultado.conCitacion ? _juzgado.text.trim() : '',
      fechaComparecencia: _resultado.conCitacion ? _comparecencia : null,
      infracciones: _resultado.conCitacion ? _infracciones.text.trim() : '',
      adjuntos: _adjuntos,
      notas: _notas.text.trim(),
    );
    final guardado = await guantera.guardarControl(
      control,
      nuevosAdjuntos: [for (final a in _nuevos) (a.bytes, a.esPdf, a.nombre)],
    );
    if (!mounted) return;
    if (widget.control == null) {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => ControlDetalle(controlId: guardado.id)));
    } else {
      Navigator.pop(context);
    }
  }

  Widget _campo(TextEditingController c, String etiqueta,
          {String? ayuda, int lineas = 1}) =>
      TextField(
        controller: c,
        minLines: 1,
        maxLines: lineas,
        decoration: InputDecoration(labelText: etiqueta, helperText: ayuda),
      );

  Widget _seccion(String titulo) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 4),
        child: Text(titulo, style: Theme.of(context).textTheme.titleMedium),
      );

  @override
  Widget build(BuildContext context) {
    final vehiculos = AppScope.guantera(context).vehiculos;
    final ahora = DateTime.now();
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.control == null ? 'Registrar control' : 'Editar control')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.schedule),
          title: Text(_formato(_fechaHora)),
          trailing: const Icon(Icons.edit_calendar),
          onTap: () async {
            final f = await _elegirFechaHora(_fechaHora,
                desde: DateTime(ahora.year - 3), hasta: ahora);
            if (f != null) setState(() => _fechaHora = f);
          },
        ),
        if (vehiculos.isNotEmpty)
          DropdownButtonFormField<String?>(
            initialValue: vehiculos.any((v) => v.id == _vehiculoId) ? _vehiculoId : null,
            decoration: const InputDecoration(labelText: 'Vehículo'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Sin vehículo')),
              for (final v in vehiculos)
                DropdownMenuItem(value: v.id, child: Text(v.patente)),
            ],
            onChanged: (v) => setState(() => _vehiculoId = v),
          ),
        _campo(_lugar, 'Lugar', ayuda: 'Calle, número o intersección, comuna'),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _ubicando ? null : _ubicar,
            icon: const Icon(Icons.my_location),
            label: Text(_ubicando
                ? 'Obteniendo ubicación…'
                : _lat == null
                    ? 'Agregar ubicación GPS'
                    : 'GPS: ${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}'),
          ),
        ),
        _seccion('Funcionario'),
        DropdownButtonFormField<Institucion>(
          initialValue: _institucion,
          decoration: const InputDecoration(labelText: 'Institución'),
          items: [
            for (final i in Institucion.values)
              DropdownMenuItem(value: i, child: Text(i.nombre)),
          ],
          onChanged: (i) => setState(() => _institucion = i!),
        ),
        _campo(_grado, 'Grado', ayuda: 'Ej. Cabo, Sargento, Teniente'),
        _campo(_nombre, 'Nombre'),
        _campo(_identificacion, 'Identificación', ayuda: 'Código o número de placa, si lo indicó'),
        _seccion('Control'),
        _campo(_motivo, 'Motivo indicado por el funcionario', lineas: 3),
        DropdownButtonFormField<ResultadoControl>(
          initialValue: _resultado,
          decoration: const InputDecoration(labelText: 'Resultado'),
          items: [
            for (final r in ResultadoControl.values)
              DropdownMenuItem(value: r, child: Text(r.nombre)),
          ],
          onChanged: (r) => setState(() => _resultado = r!),
        ),
        if (_resultado.conCitacion) ...[
          _campo(_citacion, 'N° de citación / boleta'),
          _campo(_infracciones, 'Infracción imputada', lineas: 3),
          _campo(_juzgado, 'Juzgado de Policía Local', ayuda: 'Indicado en la citación'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: Text(_comparecencia == null
                ? 'Fecha de comparecencia (opcional)'
                : 'Comparecencia: ${_formato(_comparecencia!)}'),
            subtitle: const Text('Te avisaremos el día anterior y 2 horas antes'),
            trailing: _comparecencia == null
                ? const Icon(Icons.edit_calendar)
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _comparecencia = null)),
            onTap: () async {
              final f = await _elegirFechaHora(
                _comparecencia ?? DateTime(ahora.year, ahora.month, ahora.day + 7, 9),
                desde: DateTime(ahora.year - 1),
                hasta: DateTime(ahora.year + 2),
              );
              if (f != null) setState(() => _comparecencia = f);
            },
          ),
        ],
        _seccion('Fotos y documentos'),
        const Text('Ej. foto de la citación, del lugar o de la señalización.'),
        const SizedBox(height: 8),
        BotonesArchivo(alElegir: (a) => setState(() => _nuevos.add(a))),
        for (final a in _adjuntos)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(a.esPdf ? Icons.picture_as_pdf : Icons.image_outlined),
            title: Text(a.nombre, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _adjuntos.remove(a))),
          ),
        for (final a in _nuevos)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(a.esPdf ? Icons.picture_as_pdf : Icons.image_outlined),
            title: Text(a.nombre, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _nuevos.remove(a))),
          ),
        _seccion('Notas'),
        _campo(_notas, 'Lo que ocurrió, testigos, etc.', lineas: 6),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          child: Text(_guardando ? 'Guardando…' : 'Guardar'),
        ),
        const SizedBox(height: 8),
        Text('Se guarda cifrado solo en este teléfono.',
            style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
      ]),
    );
  }
}

String _formato(DateTime d) => _fechaHoraFmt.format(d);
