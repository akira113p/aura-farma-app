// O QUE É ESTE ARQUIVO
// Cliente HTTP do app: fala com o backend (GET/POST/PATCH/DELETE), cuida do cookie de
// sessão `sid` e converte erros em ApiException. Quem usa: state/app_store.dart (todas
// as chamadas passam por aqui) e login.dart (captura ApiException). Usa: config.dart
// (URL do servidor) e core/sessao_storage.dart (guarda o cookie). Veja GUIA_FLUTTER.md → Rede.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import 'sessao_storage.dart';

/// Erro devolvido pela API (ou falha de rede, com [status] 0).
///
/// Usada para qualquer falha de comunicação. `implements Exception` marca a classe como
/// "erro que pode ser lançado e capturado" (`throw` / `on ApiException catch`).
class ApiException implements Exception {
  /// Código HTTP da resposta (401 = não autorizado, 404 = não achou...). 0 = nem chegou ao servidor.
  final int status;
  /// Texto amigável para mostrar ao usuário.
  final String message;
  /// Erros por campo enviados pelo servidor (ex.: qual campo está inválido). Vazio se não houver.
  final Map<String, String> details;

  // `[this.details = ...]` entre colchetes = parâmetro posicional opcional.
  const ApiException(this.status, this.message, [this.details = const {}]);

  @override
  /// Texto usado quando o erro é impresso (logs/depuração).
  String toString() => 'ApiException($status): $message';
}

/// Cliente HTTP do backend, com o cookie de sessão `sid` gerenciado à mão.
///
/// "Cookie" é o crachá que o servidor entrega no login e que o app reenvia em toda
/// requisição (veja GUIA_FLUTTER.md → Cookie de sessão). Aqui ele é guardado à mão,
/// porque o pacote `http` não gerencia cookies sozinho como um navegador faz.
class ApiClient {
  /// Todos os parâmetros são opcionais: nos testes dá para injetar um cliente HTTP falso,
  /// um armazenamento em memória e uma URL fixa. No app real usa os padrões (`??` = "se for nulo, use isto").
  ApiClient({http.Client? client, SessaoStorage? storage, String? baseUrl})
      : _client = client ?? http.Client(),
        _storage = storage ?? SessaoStorageSegura(),
        _baseUrl = baseUrl;

  /// O objeto que de fato faz as chamadas HTTP.
  final http.Client _client;
  /// Onde o cookie fica salvo entre aberturas do app.
  final SessaoStorage _storage;
  /// URL fixa (só testes). Nulo = usa a de `AppConfig.baseUrl`.
  final String? _baseUrl;
  /// Cookie `sid=...` em memória. Nulo = sem sessão (deslogado).
  String? _cookie;

  /// Tempo máximo de espera por resposta; passou disso vira "sem conexão".
  static const _timeoutPadrao = Duration(seconds: 20);
  /// Expressão regular que extrai `sid=VALOR` do cabeçalho Set-Cookie (para antes de `;`, `,` ou espaço).
  static final _sidRegex = RegExp(r'sid=([^;,\s]+)');

  /// URL base da API. Lida a cada chamada, então vale a troca de servidor feita no login.
  String get baseUrl => _baseUrl ?? AppConfig.baseUrl;

  /// true se há um cookie de sessão carregado/guardado.
  bool get temSessao => _cookie != null;

  /// Lê o cookie salvo para a memória.
  /// Lê o cookie salvo no aparelho para a memória. Chamada ao abrir o app (AppStore.iniciar).
  Future<void> carregarSessao() async {
    _cookie = await _storage.ler();
  }

  /// Esquece o cookie (memória e disco). Chamada no logout, quando o servidor devolve 401
  /// e quando o usuário troca de servidor.
  Future<void> limparSessao() async {
    _cookie = null;
    await _storage.apagar();
  }

  /// Atalhos para cada tipo de chamada HTTP; todos passam por `_enviar`.
  /// `path` é só o final da URL (ex.: '/estado'). Devolvem o JSON já convertido
  /// (`dynamic` = tipo livre: pode ser Map, List, texto ou null).
  Future<dynamic> get(String path, {Duration? timeout}) =>
      _enviar('GET', path, timeout: timeout);

  Future<dynamic> post(String path, [Object? body, Duration? timeout]) =>
      _enviar('POST', path, body: body, timeout: timeout);

  Future<dynamic> patch(String path, Object body) =>
      _enviar('PATCH', path, body: body);

  Future<void> delete(String path) async {
    await _enviar('DELETE', path);
  }

  /// O coração do cliente: monta a requisição, envia, trata erros e converte a resposta.
  /// Devolve o JSON decodificado (ou null se não há corpo) e lança [ApiException] em falhas.
  Future<dynamic> _enviar(String metodo, String path,
      {Object? body, Duration? timeout}) async {
    // (1) Monta a requisição: método + URL completa + cabeçalhos.
    final req = http.Request(metodo, Uri.parse('$baseUrl$path'));
    req.headers['Accept'] = 'application/json';
    // Anexa o crachá de sessão, se houver (`_cookie!` é seguro: checado na mesma linha).
    if (_cookie != null) req.headers['Cookie'] = _cookie!;
    // POST sempre manda corpo JSON (mesmo vazio `{}`); outros só se houver `body`.
    if (body != null || metodo == 'POST') {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body ?? {});
    }

    // (2) Envia e espera a resposta.
    http.Response res;
    try {
      // Primeiro chegam os cabeçalhos (stream); depois lemos o corpo inteiro. Cada etapa
      // tem limite de tempo (`timeout`).
      final stream = await _client.send(req).timeout(timeout ?? _timeoutPadrao);
      res = await http.Response.fromStream(stream)
          .timeout(timeout ?? _timeoutPadrao);
    // Qualquer falha aqui vira a mesma mensagem simples para o usuário.
    } catch (_) {
      // Rede, DNS, timeout, handshake... tudo vira "sem conexão".
      throw const ApiException(0, 'Sem conexão com o servidor.');
    }

    // (3) Se o servidor mandou um cookie novo (login), guarda.
    await _guardarCookie(res.headers['set-cookie']);

    // (4) Resposta sem corpo (204 = "sem conteúdo"): só vale checar se foi erro.
    if (res.statusCode == 204 || res.body.isEmpty) {
      // Sem corpo, mas com código de erro: lança um erro genérico.
      if (res.statusCode >= 400) {
        throw ApiException(res.statusCode, 'Erro ${res.statusCode}.');
      }
      return null;
    }

    // (5) Converte o texto JSON em Map/List. `utf8.decode` garante acentos corretos.
    dynamic dados;
    try {
      dados = jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      // Corpo que não é JSON válido: segue com null.
      dados = null;
    }

    // (6) Códigos 400+ são erro. Tenta pegar a mensagem (`error`) e os detalhes por campo (`details`) do JSON.
    if (res.statusCode >= 400) {
      var msg = 'Erro ${res.statusCode}.';
      final det = <String, String>{};
      // `is Map` confere o tipo antes de usar; `as String` converte com segurança.
      if (dados is Map) {
        if (dados['error'] is String) msg = dados['error'] as String;
        final d = dados['details'];
        if (d is Map) {
          // Copia cada par chave/valor para o mapa de detalhes, tudo como texto.
          d.forEach((k, v) => det['$k'] = '$v');
        }
      }
      throw ApiException(res.statusCode, msg, det);
    }
    // Sucesso: devolve os dados.
    return dados;
  }

  /// Procura `sid=...` no cabeçalho Set-Cookie da resposta e, se for novo, guarda na
  /// memória e no armazenamento seguro. Sem cookie novo, não faz nada.
  Future<void> _guardarCookie(String? setCookie) async {
    if (setCookie == null) return;
    // `firstMatch` devolve null se não achou o `sid`; `m.group(1)` é o valor capturado entre parênteses.
    final m = _sidRegex.firstMatch(setCookie);
    if (m == null) return;
    final novo = 'sid=${m.group(1)}';
    // Mesmo cookie de antes: evita regravar no disco à toa.
    if (novo == _cookie) return;
    _cookie = novo;
    await _storage.salvar(novo);
  }
}
