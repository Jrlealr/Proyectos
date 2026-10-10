import 'package:flutter/material.dart';

import '../guantera/modelos.dart';
import 'app_scope.dart';
import 'documentos.dart';
import 'estado.dart';

class VehiculosPantalla extends StatelessWidget {
  const VehiculosPantalla({super.key});

  @override
  Widget build(BuildContext context) {
    final guantera = AppScope.guantera(context);
    final vehiculos = guantera.vehiculos;
    if (vehiculos.isEmpty) {
      return const Vacio(
        icono: Icons.directions_car_outlined,
        texto: 'Agrega tu auto o moto para guardar sus documentos.',
      );
    }
    return ListView(children: [
      for (final v in vehiculos)
        ListTile(
          leading: Icon(v.tipo == TipoVehiculo.moto
              ? Icons.two_wheeler
              : Icons.directions_car),
          title: Text(v.patente,
              style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
          subtitle: Text(v.descripcion.isEmpty ? v.tipo.nombre : v.descripcion),
          trailing: EstadoIcono(guantera.estadoVehiculo(v.id)),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => VehiculoDetalle(vehiculoId: v.id))),
        ),
    ]);
  }
}

class VehiculoDetalle extends StatelessWidget {
  const VehiculoDetalle({super.key, required this.vehiculoId});
  final String vehiculoId;

  Future<void> _borrar(BuildContext context, Vehiculo v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Eliminar ${v.patente}?'),
        content: const Text('Se borrarán también todos sus documentos.'),
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
    await AppScope.guantera(context).borrarVehiculo(v.id);
  }

  @override
  Widget build(BuildContext context) {
    final guantera = AppScope.guantera(context);
    final v = guantera.vehiculo(vehiculoId);
    if (v == null) return const Scaffold();
    final docs = guantera.documentosDe(v.id);
    return Scaffold(
      appBar: AppBar(
        title: Text(v.patente),
        actions: [
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => VehiculoForm(vehiculo: v))),
          ),
          IconButton(
            tooltip: 'Eliminar',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _borrar(context, v),
          ),
        ],
      ),
      body: docs.isEmpty
          ? const Vacio(
              icono: Icons.folder_open,
              texto: 'Agrega el permiso de circulación, SOAP, revisión técnica y padrón.',
            )
          : ListView(children: [for (final d in docs) DocumentoTile(d)]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => DocumentoForm(vehiculoId: v.id))),
        icon: const Icon(Icons.add),
        label: const Text('Documento'),
      ),
    );
  }
}

class VehiculoForm extends StatefulWidget {
  const VehiculoForm({super.key, this.vehiculo});
  final Vehiculo? vehiculo;

  @override
  State<VehiculoForm> createState() => _VehiculoFormState();
}

class _VehiculoFormState extends State<VehiculoForm> {
  final _form = GlobalKey<FormState>();
  late final _patente = TextEditingController(text: widget.vehiculo?.patente);
  late final _marca = TextEditingController(text: widget.vehiculo?.marca);
  late final _modelo = TextEditingController(text: widget.vehiculo?.modelo);
  late final _anio =
      TextEditingController(text: widget.vehiculo?.anio?.toString());
  late TipoVehiculo _tipo = widget.vehiculo?.tipo ?? TipoVehiculo.auto;

  @override
  void dispose() {
    for (final c in [_patente, _marca, _modelo, _anio]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    await AppScope.guantera(context).guardarVehiculo(
      id: widget.vehiculo?.id,
      patente: _patente.text,
      tipo: _tipo,
      marca: _marca.text,
      modelo: _modelo.text,
      anio: int.tryParse(_anio.text),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.vehiculo == null ? 'Nuevo vehículo' : 'Editar vehículo')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          SegmentedButton<TipoVehiculo>(
            segments: const [
              ButtonSegment(
                  value: TipoVehiculo.auto,
                  icon: Icon(Icons.directions_car),
                  label: Text('Auto')),
              ButtonSegment(
                  value: TipoVehiculo.moto,
                  icon: Icon(Icons.two_wheeler),
                  label: Text('Moto')),
            ],
            selected: {_tipo},
            onSelectionChanged: (s) => setState(() => _tipo = s.first),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _patente,
            textCapitalization: TextCapitalization.characters,
            decoration:
                const InputDecoration(labelText: 'Patente', hintText: 'ABCD12'),
            validator: (s) => patenteValida(normalizarPatente(s ?? ''))
                ? null
                : 'Patente no válida',
          ),
          TextFormField(
            controller: _marca,
            decoration: const InputDecoration(labelText: 'Marca (opcional)'),
          ),
          TextFormField(
            controller: _modelo,
            decoration: const InputDecoration(labelText: 'Modelo (opcional)'),
          ),
          TextFormField(
            controller: _anio,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Año (opcional)'),
            validator: (s) {
              if (s == null || s.isEmpty) return null;
              final n = int.tryParse(s);
              return n == null || n < 1950 || n > DateTime.now().year + 1
                  ? 'Año no válido'
                  : null;
            },
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _guardar, child: const Text('Guardar')),
        ]),
      ),
    );
  }
}

class Vacio extends StatelessWidget {
  const Vacio({super.key, required this.icono, required this.texto});
  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icono, size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(texto, textAlign: TextAlign.center),
          ]),
        ),
      );
}
