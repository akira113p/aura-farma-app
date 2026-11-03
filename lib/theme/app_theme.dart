import 'package:flutter/material.dart';

/// Paleta do app (medida nos frames do Figma + tokens do web).
class AppCores {
  final Color fundo,
      superficie,
      borda,
      texto,
      textoSuave,
      textoFraco,
      destaque,
      destaqueSuave,
      sucesso,
      aviso,
      perigo;

  const AppCores({
    required this.fundo,
    required this.superficie,
    required this.borda,
    required this.texto,
    required this.textoSuave,
    required this.textoFraco,
    required this.destaque,
    required this.destaqueSuave,
    required this.sucesso,
    required this.aviso,
    required this.perigo,
  });

  static const claro = AppCores(
      fundo: Color(0xFFEBE9EA),
      superficie: Color(0xFFFFFFFF),
      borda: Color(0xFF8A8A8A),
      texto: Color(0xFF0A0A0A),
      textoSuave: Color(0xFF737373),
      textoFraco: Color(0xFFA3A3A3),
      destaque: Color(0xFFF97316),
      destaqueSuave: Color(0xFFFDC9A0),
      sucesso: Color(0xFF15803D),
      aviso: Color(0xFFB45309),
      perigo: Color(0xFFB91C1C));

  static const escuro = AppCores(
      fundo: Color(0xFF0A0A0A),
      superficie: Color(0xFF131313),
      borda: Color(0xFF3A3A3A),
      texto: Color(0xFFFAFAFA),
      textoSuave: Color(0xFFA1A1A1),
      textoFraco: Color(0xFF6B6B6B),
      destaque: Color(0xFFF97316),
      destaqueSuave: Color(0xFF5A2A0A),
      sucesso: Color(0xFF4ADE80),
      aviso: Color(0xFFFBBF24),
      perigo: Color(0xFFF87171));

  /// Escolhe a paleta pela brightness do tema atual.
  static AppCores of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? escuro : claro;
}

ThemeData _montar(AppCores c, Brightness b) {
  final base = ThemeData(
    useMaterial3: true,
    brightness: b,
    scaffoldBackgroundColor: c.fundo,
    colorScheme: ColorScheme.fromSeed(
      seedColor: c.destaque,
      brightness: b,
    ).copyWith(
      primary: c.destaque,
      onPrimary: Colors.white,
      surface: c.superficie,
      onSurface: c.texto,
      error: c.perigo,
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: c.texto, displayColor: c.texto),
    dividerColor: c.borda,
    cardColor: c.superficie,
    canvasColor: c.superficie,
    dialogTheme: DialogThemeData(backgroundColor: c.superficie),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: c.superficie),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.superficie,
      hintStyle: TextStyle(color: c.textoFraco, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c.borda),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c.borda),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c.destaque),
      ),
    ),
  );
}

ThemeData temaClaro() => _montar(AppCores.claro, Brightness.light);
ThemeData temaEscuro() => _montar(AppCores.escuro, Brightness.dark);
