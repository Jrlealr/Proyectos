import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:app_conductores/ofertas/motor_ofertas.dart';
import 'package:app_conductores/ofertas/oferta.dart';

ConfigOfertas _configReal() => ConfigOfertas.fromJson(
    jsonDecode(File('assets/config/ofertas.json').readAsStringSync())
        as Map<String, dynamic>);

/// Config real con el flag global y todas las ofertas activadas.
ConfigOfertas _configActivada() {
  final raw = jsonDecode(File('assets/config/ofertas.json').readAsStringSync())
      as Map<String, dynamic>;
  raw['habilitadas'] = true;
  for (final o in raw['ofertas'] as List) {
    (o as Map<String, dynamic>)['habilitada'] = true;
  }
  return ConfigOfertas.fromJson(raw);
}

const _soapPorVencer = ContextoOferta(
  ubicacion: 'alerta_vencimiento',
  documento: 'soap',
  diasParaVencer: 10,
);

void main() {
  test('v1: el archivo empaquetado tiene todo desactivado', () {
    final config = _configReal();
    expect(config.habilitadas, isFalse);
    expect(config.ofertas.every((o) => !o.habilitada), isTrue);
    expect(
      MotorOfertas(config)
          .ofertaPara(_soapPorVencer, usuarioPermiteOfertas: true),
      isNull,
    );
  });

  group('con ofertas activadas', () {
    final motor = MotorOfertas(_configActivada());

    test('SOAP por vencer muestra soap_compra', () {
      expect(
        motor.ofertaPara(_soapPorVencer, usuarioPermiteOfertas: true)?.id,
        'soap_compra',
      );
    });

    test('SOAP vencido también muestra la oferta', () {
      const ctx = ContextoOferta(
          ubicacion: 'alerta_vencimiento', documento: 'soap', diasParaVencer: -3);
      expect(motor.ofertaPara(ctx, usuarioPermiteOfertas: true)?.id,
          'soap_compra');
    });

    test('lejos del vencimiento no muestra nada', () {
      const ctx = ContextoOferta(
          ubicacion: 'alerta_vencimiento', documento: 'soap', diasParaVencer: 90);
      expect(motor.ofertaPara(ctx, usuarioPermiteOfertas: true), isNull);
    });

    test('revisión técnica elige su propia oferta', () {
      const ctx = ContextoOferta(
          ubicacion: 'alerta_vencimiento',
          documento: 'revision_tecnica',
          diasParaVencer: 5);
      expect(motor.ofertaPara(ctx, usuarioPermiteOfertas: true)?.id,
          'revision_tecnica_agenda');
    });

    test('usuario las apagó en Ajustes', () {
      expect(motor.ofertaPara(_soapPorVencer, usuarioPermiteOfertas: false),
          isNull);
    });

    test('nunca en Modo Fiscalización ni en Ley de Tránsito', () {
      const fisc = ContextoOferta(
          ubicacion: 'alerta_vencimiento',
          documento: 'soap',
          diasParaVencer: 10,
          enModoFiscalizacion: true);
      const ley = ContextoOferta(
          ubicacion: 'registro_parte', parteRegistrado: true, enLeyTransito: true);
      expect(motor.ofertaPara(fisc, usuarioPermiteOfertas: true), isNull);
      expect(motor.ofertaPara(ley, usuarioPermiteOfertas: true), isNull);
    });

    test('oferta descartada no reaparece', () {
      expect(
        motor.ofertaPara(_soapPorVencer,
            usuarioPermiteOfertas: true, descartadas: {'soap_compra'}),
        isNull,
      );
    });

    test('parte registrado muestra abogado_parte', () {
      const ctx =
          ContextoOferta(ubicacion: 'registro_parte', parteRegistrado: true);
      expect(motor.ofertaPara(ctx, usuarioPermiteOfertas: true)?.id,
          'abogado_parte');
    });
  });
}
