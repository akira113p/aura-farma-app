// O QUE É ESTE ARQUIVO
// Configuração de runtime do app: descobre qual é a URL do servidor (backend).
// Quem usa: main.dart (chama `AppConfig.carregar()` ao abrir), login.dart (troca o
// servidor) e core/api_client.dart (lê `baseUrl` a cada requisição).
// Usa: shared_preferences (guarda a URL no aparelho). Veja GUIA_FLUTTER.md → Rede.

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
  /// URL do servidor definida na hora de compilar/rodar com
  /// `--dart-define=API_BASE_URL=...`. `String.fromEnvironment` lê essa opção do
  /// build; vazio ('') significa "ninguém definiu".
  static const String apiBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

  /// Nome ("chave") sob o qual a URL fica guardada no aparelho (SharedPreferences:
  /// um pequeno "caderninho" de chave -> valor que sobrevive ao fechar o app).
  static const _chave = 'aurafarma.servidor';

  /// URL escolhida dentro do app (null = usar o padrão).
  static String? _salva;

  /// Lê a URL salva. Chamar uma vez antes do `runApp`.
  // (`static` = pertence à classe, não a um objeto: use `AppConfig.carregar()` direto.)
  // Devolve um Future porque ler do disco demora; quem chama usa `await`.
  static Future<void> carregar() async {
    try {
      // (1) Abre o "caderninho" do aparelho (await: espera abrir sem travar a tela).
      final p = await SharedPreferences.getInstance();
      final s = p.getString(_chave);
      // (2) Texto vazio ou ausente vira null, que significa "use o padrão".
      _salva = (s == null || s.isEmpty) ? null : s;
    // Se o disco falhar, ignora de propósito: o app segue com a URL padrão.
    } catch (_) {}
  }

  /// Salva a URL do servidor (aceita vazio/null para voltar ao padrão).
  // `entrada` pode ser nulo (String?). Chamada pela tela de login quando o usuário
  // salva (ou restaura o padrão do) endereço do servidor.
  static Future<void> definirServidor(String? entrada) async {
    // (1) Entrada vazia -> null (voltar ao padrão); senão arruma o formato da URL.
    final url = (entrada == null || entrada.trim().isEmpty)
        ? null
        : normalizarUrl(entrada);
    // (2) Atualiza a memória já, para valer mesmo que a gravação no disco falhe.
    _salva = url;
    try {
      // (3) Grava (ou apaga, se for o padrão) no aparelho.
      final p = await SharedPreferences.getInstance();
      if (url == null) {
        await p.remove(_chave);
      } else {
        await p.setString(_chave, url);
      }
    } catch (_) {}
  }

  /// A URL em uso agora.
  // `get` = parece uma variável, mas é calculada cada vez que alguém lê `AppConfig.baseUrl`.
  // Segue a ordem de prioridade descrita no topo da classe.
  static String get baseUrl {
    // `_salva!` = "tenho certeza de que não é nulo" (acabamos de checar).
    if (_salva != null) return _salva!;
    if (apiBaseUrl.isNotEmpty) return apiBaseUrl;
    // No emulador Android, `localhost` é o próprio emulador. O endereço especial
    // 10.0.2.2 aponta para o computador que roda o emulador (onde está o backend).
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:4000/api';
    return 'http://localhost:4000/api';
  }

  /// "meu-tunel.trycloudflare.com" -> "https://meu-tunel.trycloudflare.com/api".
  /// IP e localhost sem esquema usam http; o resto usa https. Garante o `/api` no fim.
  // Recebe o que o usuário digitou e devolve uma URL completa e válida.
  // Passos: (1) tira espaços e "/" finais; (2) coloca http/https se faltar;
  // (3) garante "/api" no fim.
  static String normalizarUrl(String entrada) {
    var s = entrada.trim();
    // Remove todas as barras do final ("site.com///" vira "site.com").
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    // Sem esquema (http/https) digitado: decide qual usar.
    if (!s.contains('://')) {
      // Expressão regular (padrão de texto): casa "localhost" ou um IP como 192.168.0.10,
      // com porta opcional. Redes locais não têm certificado, então usam http.
      final local = RegExp(r'^(localhost|\d{1,3}(\.\d{1,3}){3})(:\d+)?(/|$)')
          .hasMatch(s);
      // Endereço local -> http; qualquer outro (ex.: túnel) -> https.
      s = '${local ? 'http' : 'https'}://$s';
    }
    // Todas as rotas do backend ficam sob /api.
    if (!s.endsWith('/api')) s = '$s/api';
    return s;
  }
}
