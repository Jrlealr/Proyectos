import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'control.dart';
import 'modelos.dart';

/// Días antes del vencimiento en que se avisa (0 = el mismo día).
const diasDeAviso = [30, 15, 1, 0];

/// Hora local del aviso.
const horaAviso = 9;

class AlertaProgramada {
  const AlertaProgramada(this.id, this.fecha, this.titulo, this.cuerpo);
  final int id;
  final DateTime fecha;
  final String titulo;
  final String cuerpo;
}

/// ID estable (FNV-1a de 31 bits) para la notificación [indice] de un documento.
int idNotificacion(String documentoId, int indice) {
  var h = 0x811c9dc5;
  for (final c in documentoId.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0x7fffffff;
  }
  // Se reservan 8 slots por documento.
  return ((h & 0x0fffffff) << 3) | indice;
}

/// Calcula las alertas futuras de un documento. Función pura (testeable).
List<AlertaProgramada> planificarAlertas(
    Documento doc, String? patente, DateTime ahora) {
  final v = doc.vencimiento;
  if (v == null) return const [];
  final quien = patente == null ? '' : ' de $patente';
  final alertas = <AlertaProgramada>[];
  for (var i = 0; i < diasDeAviso.length; i++) {
    final dias = diasDeAviso[i];
    final fecha = DateTime(v.year, v.month, v.day - dias, horaAviso);
    if (!fecha.isAfter(ahora)) continue;
    final cuando = switch (dias) {
      0 => 'vence hoy',
      1 => 'vence mañana',
      _ => 'vence en $dias días',
    };
    alertas.add(AlertaProgramada(
      idNotificacion(doc.id, i),
      fecha,
      '${doc.tipo.nombre}$quien',
      'Tu ${doc.tipo.nombre.toLowerCase()}$quien $cuando.',
    ));
  }
  return alertas;
}

/// Avisos de comparecencia al Juzgado: el día anterior a las 9:00 y
/// 2 horas antes. Función pura (testeable).
List<AlertaProgramada> planificarComparecencia(Control c, DateTime ahora) {
  final f = c.fechaComparecencia;
  if (f == null) return const [];
  final juzgado = c.juzgado.isEmpty ? 'el Juzgado de Policía Local' : c.juzgado;
  final candidatos = [
    (DateTime(f.year, f.month, f.day - 1, horaAviso), 'Mañana debes presentarte en $juzgado.'),
    (f.subtract(const Duration(hours: 2)), 'Hoy debes presentarte en $juzgado.'),
  ];
  return [
    for (final (i, (fecha, cuerpo)) in candidatos.indexed)
      if (fecha.isAfter(ahora))
        AlertaProgramada(idNotificacion('control:${c.id}', i), fecha,
            'Citación ${c.patente}'.trim(), cuerpo),
  ];
}

abstract class Alertas {
  Future<void> programar(Documento doc, String? patente);
  Future<void> cancelar(Documento doc);
  Future<void> programarControl(Control c);
  Future<void> cancelarControl(Control c);
}

/// Notificaciones locales del sistema. No usa servidores.
class AlertasLocales implements Alertas {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _listo = false;

  Future<void> iniciar() async {
    if (_listo) return;
    tzdata.initializeTimeZones();
    try {
      final zona = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zona.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('America/Santiago'));
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _listo = true;
  }

  static const _detalles = NotificationDetails(
    android: AndroidNotificationDetails(
      'vencimientos',
      'Vencimientos',
      channelDescription: 'Avisos de documentos por vencer',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  @override
  Future<void> programar(Documento doc, String? patente) async {
    await cancelar(doc);
    await _agendar(planificarAlertas(doc, patente, DateTime.now()));
  }

  @override
  Future<void> programarControl(Control c) async {
    await cancelarControl(c);
    await _agendar(planificarComparecencia(c, DateTime.now()));
  }

  @override
  Future<void> cancelarControl(Control c) async {
    await iniciar();
    for (var i = 0; i < 2; i++) {
      await _plugin.cancel(id: idNotificacion('control:${c.id}', i));
    }
  }

  Future<void> _agendar(List<AlertaProgramada> alertas) async {
    await iniciar();
    for (final a in alertas) {
      await _plugin.zonedSchedule(
        id: a.id,
        title: a.titulo,
        body: a.cuerpo,
        scheduledDate: tz.TZDateTime.from(a.fecha, tz.local),
        notificationDetails: _detalles,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  @override
  Future<void> cancelar(Documento doc) async {
    await iniciar();
    for (var i = 0; i < diasDeAviso.length; i++) {
      await _plugin.cancel(id: idNotificacion(doc.id, i));
    }
  }
}
