import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'oferta.dart';

/// Estado local de la pantalla donde se evalúa una oferta.
/// Todo se calcula en el dispositivo; nada se envía a un servidor.
class ContextoOferta {
  const ContextoOferta({
    required this.ubicacion,
    this.documento,
    this.diasParaVencer,
    this.sinSeguroVoluntario = false,
    this.parteRegistrado = false,
    this.recordatorioMantencion = false,
    this.enModoFiscalizacion = false,
    this.enLeyTransito = false,
  });

  final String ubicacion;
  final String? documento;

  /// Negativo si el documento ya venció.
  final int? diasParaVencer;
  final bool sinSeguroVoluntario;
  final bool parteRegistrado;
  final bool recordatorioMantencion;
  final bool enModoFiscalizacion;
  final bool enLeyTransito;
}

class MotorOfertas {
  MotorOfertas(this.config);

  final ConfigOfertas config;

  static Future<MotorOfertas> cargar() async {
    try {
      final json = await rootBundle.loadString('assets/config/ofertas.json');
      return MotorOfertas(
          ConfigOfertas.fromJson(jsonDecode(json) as Map<String, dynamic>));
    } catch (_) {
      return MotorOfertas(ConfigOfertas.desactivada);
    }
  }

  /// Devuelve como máximo una oferta para el contexto, o null.
  ///
  /// [usuarioPermiteOfertas]: interruptor en Ajustes → "Ofertas y beneficios".
  /// [descartadas]: ids que el usuario descartó en el ciclo de vencimiento actual.
  Oferta? ofertaPara(
    ContextoOferta ctx, {
    required bool usuarioPermiteOfertas,
    Set<String> descartadas = const {},
  }) {
    if (!config.habilitadas || !usuarioPermiteOfertas) return null;
    if (ctx.enModoFiscalizacion || ctx.enLeyTransito) return null;

    for (final o in config.ofertas) {
      if (!o.habilitada || descartadas.contains(o.id)) continue;
      if (o.ubicacion != ctx.ubicacion) continue;
      if (o.documento != null && o.documento != ctx.documento) continue;
      if (_cumple(o.disparador, ctx)) return o;
    }
    return null;
  }

  bool _cumple(Disparador d, ContextoOferta ctx) {
    if (d.diasAntesVencimiento != null) {
      final dias = ctx.diasParaVencer;
      if (dias == null) return false;
      if (dias < 0) return d.incluirVencido;
      return dias <= d.diasAntesVencimiento!;
    }
    return (d.sinSeguroVoluntario && ctx.sinSeguroVoluntario) ||
        (d.parteRegistrado && ctx.parteRegistrado) ||
        (d.recordatorioMantencion && ctx.recordatorioMantencion);
  }
}
