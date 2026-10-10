import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../guantera/modelos.dart';

final formatoFecha = DateFormat('dd-MM-yyyy');

Color colorEstado(EstadoVencimiento e, ColorScheme c) => switch (e) {
      EstadoVencimiento.vencido => c.error,
      EstadoVencimiento.porVencer => Colors.orange.shade800,
      EstadoVencimiento.vigente => Colors.green.shade700,
      EstadoVencimiento.sinVencimiento => c.outline,
    };

IconData iconoEstado(EstadoVencimiento e) => switch (e) {
      EstadoVencimiento.vencido => Icons.error,
      EstadoVencimiento.porVencer => Icons.warning_amber,
      EstadoVencimiento.vigente => Icons.check_circle,
      EstadoVencimiento.sinVencimiento => Icons.description_outlined,
    };

String textoEstado(Documento d, DateTime hoy) {
  final dias = diasParaVencer(d, hoy);
  if (dias == null) return 'Sin vencimiento';
  final fecha = formatoFecha.format(d.vencimiento!);
  if (dias < 0) return 'Vencido el $fecha';
  if (dias == 0) return 'Vence hoy';
  if (dias == 1) return 'Vence mañana';
  return 'Vence el $fecha ($dias días)';
}

class EstadoIcono extends StatelessWidget {
  const EstadoIcono(this.estado, {super.key});
  final EstadoVencimiento estado;

  @override
  Widget build(BuildContext context) => Icon(
        iconoEstado(estado),
        color: colorEstado(estado, Theme.of(context).colorScheme),
      );
}
