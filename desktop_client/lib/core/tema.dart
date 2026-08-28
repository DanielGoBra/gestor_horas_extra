import 'dart:ui';

import 'package:flutter/material.dart';

class Paleta {
  static const Color pantone300 = Color(0xFF005DB4);
  static const Color pantone362 = Color(0xFF6C9B3B);
  static const Color pantone375 = Color(0xFFA9D42D);
  static const Color pantone112 = Color(0xFFF6D600);
  static const Color pantone130 = Color(0xFFE4A612);
  static const Color tinta = Color(0xFF0B2540);
  static const Color tintaSuave = Color(0xFF3D5A73);
  static const Color rechazo = Color(0xFFC62828);
}

class TemaApp {
  static ThemeData construir() {
    const semilla = Paleta.pantone300;
    final esquema = ColorScheme.fromSeed(
      seedColor: semilla,
      primary: Paleta.pantone300,
      secondary: Paleta.pantone362,
      tertiary: Paleta.pantone375,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: esquema,
      scaffoldBackgroundColor: Colors.transparent,
      fontFamily: 'Segoe UI',
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
          color: Paleta.tinta,
        ),
        titleLarge: TextStyle(fontWeight: FontWeight.w800, color: Paleta.tinta),
        titleMedium: TextStyle(fontWeight: FontWeight.w800, color: Paleta.tinta),
        bodyMedium: TextStyle(
          color: Paleta.tinta,
          height: 1.4,
          fontWeight: FontWeight.w600,
        ),
        bodySmall: TextStyle(
          color: Paleta.tinta,
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
        labelLarge: TextStyle(fontWeight: FontWeight.w800, color: Paleta.tinta),
        labelMedium: TextStyle(fontWeight: FontWeight.w700, color: Paleta.tinta),
        labelSmall: TextStyle(fontWeight: FontWeight.w700, color: Paleta.tinta),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.94),
        hintStyle: const TextStyle(
          color: Paleta.tintaSuave,
          fontWeight: FontWeight.w600,
        ),
        labelStyle: const TextStyle(
          color: Paleta.tinta,
          fontWeight: FontWeight.w700,
        ),
        floatingLabelBehavior: FloatingLabelBehavior.never,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFB7C4D4)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFB7C4D4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Paleta.pantone300, width: 1.6),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(Colors.white),
          elevation: const WidgetStatePropertyAll(10),
          shadowColor: WidgetStatePropertyAll(Colors.black.withValues(alpha: 0.18)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Color(0xFFD0D7DE)),
            ),
          ),
        ),
        textStyle: const TextStyle(
          color: Paleta.tinta,
          fontWeight: FontWeight.w600,
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(Colors.white),
          elevation: const WidgetStatePropertyAll(10),
          shadowColor: WidgetStatePropertyAll(Colors.black.withValues(alpha: 0.18)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Color(0xFFD0D7DE)),
            ),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: Paleta.pantone300,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF9AA8B8),
          disabledForegroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Paleta.tinta,
          backgroundColor: Colors.white,
          disabledForegroundColor: const Color(0xFF5A6B7A),
          disabledBackgroundColor: const Color(0xFFE8EEF4),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          side: const BorderSide(color: Paleta.pantone300, width: 1.8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.96),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dataTableTheme: const DataTableThemeData(
        headingTextStyle: TextStyle(
          fontWeight: FontWeight.w800,
          color: Paleta.tinta,
          fontSize: 13,
        ),
        dataTextStyle: TextStyle(
          color: Paleta.tinta,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        headingRowColor: WidgetStatePropertyAll(Color(0x14005DB4)),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          color: Paleta.tinta,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  static Color colorEstado(String estado) {
    switch (estado) {
      case 'PENDIENTE_APROBACION':
        return const Color(0xFF9A6700);
      case 'APROBADA':
        return const Color(0xFF1B5E20);
      case 'RECHAZADA':
        return Paleta.rechazo;
      case 'CERRADA_EN_NOMINA':
        return Paleta.pantone300;
      default:
        return Paleta.tinta;
    }
  }

  static Color fondoEstado(String estado) {
    switch (estado) {
      case 'PENDIENTE_APROBACION':
        return const Color(0xFFFFE082);
      case 'APROBADA':
        return const Color(0xFFC8E6C9);
      case 'RECHAZADA':
        return const Color(0xFFFFCDD2);
      case 'CERRADA_EN_NOMINA':
        return const Color(0xFFBBDEFB);
      default:
        return const Color(0xFFE0E0E0);
    }
  }

  static String etiquetaEstado(String estado) {
    switch (estado) {
      case 'PENDIENTE_APROBACION':
        return 'En revisión';
      case 'APROBADA':
        return 'Aprobado';
      case 'RECHAZADA':
        return 'Rechazado';
      case 'CERRADA_EN_NOMINA':
        return 'En nómina';
      default:
        return estado;
    }
  }

  static Color colorTipoHora(String codigo) {
    switch (codigo) {
      case 'EXTRA_DIURNA':
        return Paleta.pantone375;
      case 'EXTRA_NOCTURNA':
        return Paleta.pantone300;
      case 'DOMINICAL_FESTIVA':
        return Paleta.pantone130;
      default:
        return Paleta.tintaSuave;
    }
  }
}

class FondoCorporativo extends StatelessWidget {
  final Widget child;
  const FondoCorporativo({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Paleta.pantone300,
            Color(0xFF0A7BC2),
            Paleta.pantone362,
            Paleta.pantone375,
          ],
          stops: [0.0, 0.38, 0.72, 1.0],
        ),
      ),
      child: child,
    );
  }
}

class Vidrio extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radio;
  final bool expandir;

  const Vidrio({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radio = 22,
    this.expandir = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radio),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: expandir ? double.infinity : null,
          height: expandir ? double.infinity : null,
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radio),
            border: Border.all(color: Colors.white.withValues(alpha: 0.45), width: 1.2),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.88),
                Colors.white.withValues(alpha: 0.72),
              ],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
