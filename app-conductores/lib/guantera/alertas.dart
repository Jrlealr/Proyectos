import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

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

abstract class Alertas {
  Future<void> programar(Documento doc, String? patente);
  Future<void> cancelar(Documento doc);
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
    await iniciar();
    await cancelar(doc);
    for (final a in planificarAlertas(doc, patente, DateTime.now())) {
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
