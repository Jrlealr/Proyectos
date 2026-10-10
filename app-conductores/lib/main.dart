import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import 'guantera/alertas.dart';
import 'guantera/almacen.dart';
import 'guantera/cifrado.dart';
import 'guantera/guantera.dart';
import 'ley/ley.dart';
import 'ley/multas.dart';
import 'ofertas/motor_ofertas.dart';
import 'ui/app_scope.dart';
import 'ui/inicio.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await pdfrxFlutterInitialize();
  final directorio = await getApplicationSupportDirectory();
  final guantera = Guantera(
    AlmacenGuantera(directorio, Cifrador(ClaveAlmacenSeguro())),
    AlertasLocales(),
  );
  await guantera.cargar();
  final ofertas = await MotorOfertas.cargar();
  final ley = await Ley.cargar();
  final utm = await Utm.cargar();
  runApp(AppConductores(
      guantera: guantera, ofertas: ofertas, ley: ley, utm: utm));
}

class AppConductores extends StatelessWidget {
  const AppConductores(
      {super.key,
      required this.guantera,
      required this.ofertas,
      this.ley,
      this.utm});

  final Guantera guantera;
  final MotorOfertas ofertas;
  final Ley? ley;
  final Utm? utm;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      guantera: guantera,
      ofertas: ofertas,
      ley: ley,
      utm: utm,
      child: MaterialApp(
        title: 'App Conductores',
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        locale: const Locale('es', 'CL'),
        supportedLocales: const [Locale('es', 'CL'), Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const Inicio(),
      ),
    );
  }
}
