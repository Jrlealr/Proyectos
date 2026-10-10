import 'package:flutter/material.dart';

import '../guantera/modelos.dart';
import 'app_scope.dart';
import 'controles.dart';
import 'documentos.dart';
import 'fiscalizacion.dart';
import 'ley.dart';
import 'oferta_boton.dart';
import 'vehiculos.dart';

class Inicio extends StatefulWidget {
  const Inicio({super.key});

  @override
  State<Inicio> createState() => _InicioState();
}

class _InicioState extends State<Inicio> {
  int _tab = 0;

  static const _titulos = [
    'Mis vehículos',
    'Mis documentos',
    'Vencimientos',
    'Controles',
    'Ley de Tránsito',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titulos[_tab]),
        actions: [
          IconButton(
            tooltip: 'Ajustes',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const Ajustes())),
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
                textStyle:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              onPressed: () => abrirFiscalizacion(context),
              icon: const Icon(Icons.local_police),
              label: const Text('MODO FISCALIZACIÓN'),
            ),
          ),
        ),
        Expanded(
          child: switch (_tab) {
            0 => const VehiculosPantalla(),
            1 => const _DocumentosPersonales(),
            2 => const _Vencimientos(),
            3 => const ControlesPantalla(),
            _ => const LeyPantalla(),
          },
        ),
      ]),
      floatingActionButton: switch (_tab) {
        0 => FloatingActionButton.extended(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const VehiculoForm())),
            icon: const Icon(Icons.add),
            label: const Text('Vehículo'),
          ),
        1 => FloatingActionButton.extended(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const DocumentoForm())),
            icon: const Icon(Icons.add),
            label: const Text('Documento'),
          ),
        3 => FloatingActionButton.extended(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ControlForm())),
            icon: const Icon(Icons.add),
            label: const Text('Control'),
          ),
        _ => null,
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.directions_car_outlined), label: 'Vehículos'),
          NavigationDestination(
              icon: Icon(Icons.badge_outlined), label: 'Personales'),
          NavigationDestination(
              icon: Icon(Icons.notifications_outlined), label: 'Vencimientos'),
          NavigationDestination(
              icon: Icon(Icons.local_police_outlined), label: 'Controles'),
          NavigationDestination(icon: Icon(Icons.gavel), label: 'Ley'),
        ],
      ),
    );
  }
}

class _DocumentosPersonales extends StatelessWidget {
  const _DocumentosPersonales();

  @override
  Widget build(BuildContext context) {
    final docs = AppScope.guantera(context).documentosDe(null);
    if (docs.isEmpty) {
      return const Vacio(
        icono: Icons.badge_outlined,
        texto: 'Guarda aquí tu licencia de conducir y cédula de identidad.',
      );
    }
    return ListView(children: [for (final d in docs) DocumentoTile(d)]);
  }
}

class _Vencimientos extends StatelessWidget {
  const _Vencimientos();

  @override
  Widget build(BuildContext context) {
    final guantera = AppScope.guantera(context);
    final docs = guantera.vencimientos;
    if (docs.isEmpty) {
      return const Vacio(
        icono: Icons.event_available,
        texto: 'Cuando agregues documentos con fecha de vencimiento, '
            'aparecerán aquí y te avisaremos antes de que venzan.',
      );
    }
    return ListView(children: [
      for (final d in docs) ...[
        DocumentoTile(d, mostrarVehiculo: true),
        if (estadoDe(d, guantera.hoy) != EstadoVencimiento.vigente)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OfertaBoton(
              contexto: OfertaBoton.contextoVencimiento(d, guantera.hoy),
              ciclo: OfertaBoton.cicloDe(d),
            ),
          ),
      ],
    ]);
  }
}

class Ajustes extends StatelessWidget {
  const Ajustes({super.key});

  @override
  Widget build(BuildContext context) {
    final guantera = AppScope.guantera(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(children: [
        SwitchListTile(
          title: const Text('Ofertas y beneficios'),
          subtitle: const Text(
              'Sugerencias opcionales (ej. comprar SOAP) junto a tus alertas.'),
          value: guantera.permiteOfertas,
          onChanged: guantera.cambiarPermiteOfertas,
        ),
        const ListTile(
          leading: Icon(Icons.lock_outline),
          title: Text('Tus datos'),
          subtitle: Text(
              'Tus documentos se guardan cifrados solo en este teléfono. '
              'No se envían a ningún servidor.'),
        ),
      ]),
    );
  }
}
