import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import 'sessao_storage.dart';

/// Erro devolvido pela API (ou falha de rede, com [status] 0).
class ApiException implements Exception {
  final int status;
  final String message;
  final Map<String, String> details;

  const ApiException(this.status, this.message, [this.details = const {}]);

  @override
  String toString() => 'ApiException($status): $message';
}

/// Cliente HTTP do backend, com o cookie de sessão `sid` gerenciado à mão.
class ApiClient {
  ApiClient({http.Client? client, SessaoStorage? storage, String? baseUrl})
      : _client = client ?? http.Client(),
        _storage = storage ?? SessaoStorageSegura(),
        _baseUrl = baseUrl;

  final http.Client _client;
  final SessaoStorage _storage;
  final String? _baseUrl;
  String? _cookie;

  static const _timeoutPadrao = Duration(seconds: 20);
  static final _sidRegex = RegExp(r'sid=([^;,\s]+)');

  String get baseUrl => _baseUrl ?? AppConfig.baseUrl;

  bool get temSessao => _cookie != null;

  /// Lê o cookie salvo para a memória.
  Future<void> carregarSessao() async {
    _cookie = await _storage.ler();
  }

  Future<void> limparSessao() async {
    _cookie = null;
    await _storage.apagar();
  }

  Future<dynamic> get(String path, {Duration? timeout}) =>
      _enviar('GET', path, timeout: timeout);

  Future<dynamic> post(String path, [Object? body, Duration? timeout]) =>
      _enviar('POST', path, body: body, timeout: timeout);

  Future<dynamic> patch(String path, Object body) =>
      _enviar('PATCH', path, body: body);

  Future<void> delete(String path) async {
    await _enviar('DELETE', path);
  }

  Future<dynamic> _enviar(String metodo, String path,
      {Object? body, Duration? timeout}) async {
    final req = http.Request(metodo, Uri.parse('$baseUrl$path'));
    req.headers['Accept'] = 'application/json';
    if (_cookie != null) req.headers['Cookie'] = _cookie!;
    if (body != null || metodo == 'POST') {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body ?? {});
    }

    http.Response res;
    try {
      final stream = await _client.send(req).timeout(timeout ?? _timeoutPadrao);
      res = await http.Response.fromStream(stream)
          .timeout(timeout ?? _timeoutPadrao);
    } catch (_) {
      // Rede, DNS, timeout, handshake... tudo vira "sem conexão".
      throw const ApiException(0, 'Sem conexão com o servidor.');
    }

    await _guardarCookie(res.headers['set-cookie']);

    if (res.statusCode == 204 || res.body.isEmpty) {
      if (res.statusCode >= 400) {
        throw ApiException(res.statusCode, 'Erro ${res.statusCode}.');
      }
      return null;
    }

    dynamic dados;
    try {
      dados = jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      dados = null;
    }

    if (res.statusCode >= 400) {
      var msg = 'Erro ${res.statusCode}.';
      final det = <String, String>{};
      if (dados is Map) {
        if (dados['error'] is String) msg = dados['error'] as String;
        final d = dados['details'];
        if (d is Map) {
          d.forEach((k, v) => det['$k'] = '$v');
        }
      }
      throw ApiException(res.statusCode, msg, det);
    }
    return dados;
  }

  Future<void> _guardarCookie(String? setCookie) async {
    if (setCookie == null) return;
    final m = _sidRegex.firstMatch(setCookie);
    if (m == null) return;
    final novo = 'sid=${m.group(1)}';
    if (novo == _cookie) return;
    _cookie = novo;
    await _storage.salvar(novo);
  }
}
