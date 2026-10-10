import 'package:flutter/widgets.dart';

import '../guantera/guantera.dart';
import '../ley/ley.dart';
import '../ley/multas.dart';
import '../ofertas/motor_ofertas.dart';

/// Da acceso a la guantera y al motor de ofertas en todo el árbol de widgets
/// y reconstruye a los dependientes cuando la guantera cambia.
class AppScope extends InheritedNotifier<Guantera> {
  const AppScope({
    super.key,
    required Guantera guantera,
    required this.ofertas,
    this.ley,
    this.utm,
    required super.child,
  }) : super(notifier: guantera);

  final MotorOfertas ofertas;

  /// null si el texto de la ley no está empaquetado.
  final Ley? ley;

  /// Valor UTM para convertir multas a pesos (null si no está empaquetado).
  final Utm? utm;

  static AppScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  static Guantera guantera(BuildContext context) => of(context).notifier!;
}
