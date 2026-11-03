import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

/// Configuração de runtime do app.
///
/// A URL do servidor vem, em ordem de prioridade, de:
/// 1. a que você digitou na tela de login ("Servidor") — fica salva no aparelho;
/// 2. `--dart-define=API_BASE_URL=...` na hora do build/run;
/// 3. o padrão: Android (emulador) -> 10.0.2.2, resto -> localhost.
class AppConfig {
  static const String apiBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

  static const _chave = 'aurafarma.servidor';

  /// URL escolhida dentro do app (null = usar o padrão).
  static String? _salva;

  /// Lê a URL salva. Chamar uma vez antes do `runApp`.
  static Future<void> carregar() async {
    try {
      final p = await SharedPreferences.getInstance();
      final s = p.getString(_chave);
      _salva = (s == null || s.isEmpty) ? null : s;
    } catch (_) {}
  }

  /// Salva a URL do servidor (aceita vazio/null para voltar ao padrão).
  static Future<void> definirServidor(String? entrada) async {
    final url = (entrada == null || entrada.trim().isEmpty)
        ? null
        : normalizarUrl(entrada);
    _salva = url;
    try {
      final p = await SharedPreferences.getInstance();
      if (url == null) {
        await p.remove(_chave);
      } else {
        await p.setString(_chave, url);
      }
    } catch (_) {}
  }

  /// A URL em uso agora.
  static String get baseUrl {
    if (_salva != null) return _salva!;
    if (apiBaseUrl.isNotEmpty) return apiBaseUrl;
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:4000/api';
    return 'http://localhost:4000/api';
  }

  /// "meu-tunel.trycloudflare.com" -> "https://meu-tunel.trycloudflare.com/api".
  /// IP e localhost sem esquema usam http; o resto usa https. Garante o `/api` no fim.
  static String normalizarUrl(String entrada) {
    var s = entrada.trim();
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    if (!s.contains('://')) {
      final local = RegExp(r'^(localhost|\d{1,3}(\.\d{1,3}){3})(:\d+)?(/|$)')
          .hasMatch(s);
      s = '${local ? 'http' : 'https'}://$s';
    }
    if (!s.endsWith('/api')) s = '$s/api';
    return s;
  }
}
