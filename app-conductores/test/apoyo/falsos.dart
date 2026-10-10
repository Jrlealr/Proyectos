import 'dart:io';

import 'package:app_conductores/guantera/alertas.dart';
import 'package:app_conductores/guantera/almacen.dart';
import 'package:app_conductores/guantera/cifrado.dart';
import 'package:app_conductores/guantera/guantera.dart';
import 'package:app_conductores/guantera/modelos.dart';

class ClaveFija implements ProveedorClave {
  ClaveFija([int semilla = 7]) : _clave = List.filled(32, semilla);
  final List<int> _clave;
  @override
  Future<List<int>> clave() async => _clave;
}

class AlertasFalsas implements Alertas {
  final programadas = <String, String?>{};
  final canceladas = <String>[];

  @override
  Future<void> programar(Documento doc, String? patente) async =>
      programadas[doc.id] = patente;

  @override
  Future<void> cancelar(Documento doc) async {
    canceladas.add(doc.id);
    programadas.remove(doc.id);
  }
}

Future<(Guantera, AlertasFalsas, AlmacenGuantera)> guanteraDePrueba(
    Directory dir, DateTime hoy) async {
  final alertas = AlertasFalsas();
  final almacen = AlmacenGuantera(dir, Cifrador(ClaveFija()));
  final g = Guantera(almacen, alertas, reloj: () => hoy);
  await g.cargar();
  return (g, alertas, almacen);
}
