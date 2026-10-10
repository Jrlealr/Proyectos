import 'package:flutter/widgets.dart';

import '../guantera/guantera.dart';
import '../ofertas/motor_ofertas.dart';

/// Da acceso a la guantera y al motor de ofertas en todo el árbol de widgets
/// y reconstruye a los dependientes cuando la guantera cambia.
class AppScope extends InheritedNotifier<Guantera> {
  const AppScope({
    super.key,
    required Guantera guantera,
    required this.ofertas,
    required super.child,
  }) : super(notifier: guantera);

  final MotorOfertas ofertas;

  static AppScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  static Guantera guantera(BuildContext context) => of(context).notifier!;
}
