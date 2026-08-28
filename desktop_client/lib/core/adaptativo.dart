import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class Roturas {
  static const navCompacta = 980.0;
  static const tablaCompacta = 880.0;
  static const metricasApiladas = 740.0;
  static const paginaBaja = 640.0;
}

class ScrollEscritorio extends MaterialScrollBehavior {
  const ScrollEscritorio();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}
