import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../models.dart';

enum StatusAuth { carregando, deslogado, logado }

/// Estado global do app: sessão, dados da farmácia e tema.
class AppStore extends ChangeNotifier {
  AppStore({ApiClient? api}) : api = api ?? ApiClient();

  final ApiClient api;

  static const _chaveTema = 'aurafarma.tema';

  StatusAuth status = StatusAuth.carregando;
  Usuario? usuario;
  Estado estado = Estado.vazio;
  bool carregandoEstado = false;
  String? erroEstado;
  ThemeMode tema = ThemeMode.light;

  /// Carrega tema + cookie salvo -> /auth/me -> estado.
  Future<void> iniciar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      tema = prefs.getString(_chaveTema) == 'escuro'
          ? ThemeMode.dark
          : ThemeMode.light;
    } catch (_) {}
    await api.carregarSessao();
    if (!api.temSessao) {
      status = StatusAuth.deslogado;
      notifyListeners();
      return;
    }
    try {
      final r = await api.get('/auth/me');
      usuario = Usuario.fromJson(Map<String, dynamic>.from(r['user'] as Map));
      status = StatusAuth.logado;
      notifyListeners();
      await recarregar();
    } on ApiException catch (e) {
      if (e.status == 401) await api.limparSessao();
      // Sem conexão: sem como validar a sessão, cai no login (cookie fica salvo).
      status = StatusAuth.deslogado;
      notifyListeners();
    }
  }

  /// Lança [ApiException] em caso de erro.
  Future<void> entrar(String identificador, String senha) async {
    final r = await api.post(
        '/auth/login', {'identifier': identificador, 'password': senha});
    usuario = Usuario.fromJson(Map<String, dynamic>.from(r['user'] as Map));
    estado = Estado.vazio;
    erroEstado = null;
    status = StatusAuth.logado;
    notifyListeners();
    await recarregar();
  }

  Future<void> sair() async {
    try {
      await api.post('/auth/logout');
    } catch (_) {}
    await _deslogarLocal();
  }

  Future<void> _deslogarLocal() async {
    await api.limparSessao();
    usuario = null;
    estado = Estado.vazio;
    erroEstado = null;
    status = StatusAuth.deslogado;
    notifyListeners();
  }

  /// Executa uma ação da API; 401 desloga localmente e relança.
  Future<T> _proteger<T>(Future<T> Function() acao) async {
    try {
      return await acao();
    } on ApiException catch (e) {
      if (e.status == 401) await _deslogarLocal();
      rethrow;
    }
  }

  Future<void> recarregar() async {
    carregandoEstado = true;
    erroEstado = null;
    notifyListeners();
    try {
      final r = await _proteger(() => api.get('/estado'));
      estado = Estado.fromJson(Map<String, dynamic>.from(r as Map));
    } on ApiException catch (e) {
      erroEstado = e.message;
    } catch (_) {
      erroEstado = 'Não foi possível carregar os dados.';
    }
    carregandoEstado = false;
    notifyListeners();
  }

  Future<void> popularExemplo() async {
    final r = await _proteger(() => api.post('/estado/seed'));
    estado = Estado.fromJson(Map<String, dynamic>.from(r as Map));
    notifyListeners();
  }

  void alternarTema() {
    tema = tema == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    SharedPreferences.getInstance().then((p) {
      p.setString(_chaveTema, tema == ThemeMode.dark ? 'escuro' : 'claro');
    }).catchError((_) {});
  }

  // ------------------------------------------------------------ solicitados

  Future<void> registrarSolicitacao(String nome, String nota) async {
    final r = await _proteger(
        () => api.post('/solicitados', {'name': nome, 'note': nota}));
    final nova =
        Solicitacao.fromJson(Map<String, dynamic>.from(r['request'] as Map));
    final lista = [...estado.solicitacoes];
    final i = lista.indexWhere((s) => s.id == nova.id);
    if (i >= 0) {
      lista[i] = nova;
    } else {
      lista.add(nova);
    }
    estado = estado.copyWith(solicitacoes: lista);
    notifyListeners();
  }

  Future<void> somarSolicitacao(Solicitacao s) async {
    final r = await _proteger(
        () => api.patch('/solicitados/${s.id}', {'count': s.pedidos + 1}));
    final nova =
        Solicitacao.fromJson(Map<String, dynamic>.from(r['request'] as Map));
    estado = estado.copyWith(
      solicitacoes:
          estado.solicitacoes.map((x) => x.id == nova.id ? nova : x).toList(),
    );
    notifyListeners();
  }

  Future<void> removerSolicitacao(String id) async {
    await _proteger(() => api.delete('/solicitados/$id'));
    estado = estado.copyWith(
      solicitacoes: estado.solicitacoes.where((x) => x.id != id).toList(),
    );
    notifyListeners();
  }

  // --------------------------------------------------------------- contagem

  /// [novoEstoquePorPid]: id do produto -> estoque contado.
  Future<void> aplicarContagem(Map<String, int> novoEstoquePorPid) async {
    final ajustes = novoEstoquePorPid.entries
        .map((e) => {'pid': e.key, 'newStock': e.value})
        .toList();
    final r = await _proteger(
        () => api.post('/contagem', {'adjustments': ajustes}));
    final contagem =
        Contagem.fromJson(Map<String, dynamic>.from(r['count'] as Map));
    final atualizados = {
      for (final p in (r['updatedProducts'] as List? ?? const []))
        Medicamentos.fromJson(Map<String, dynamic>.from(p as Map)).id:
            Medicamentos.fromJson(Map<String, dynamic>.from(p)),
    };
    estado = estado.copyWith(
      produtos: estado.produtos.map((p) => atualizados[p.id] ?? p).toList(),
      contagens: [contagem, ...estado.contagens],
    );
    notifyListeners();
  }

  // ---------------------------------------------------------------- scanner

  Medicamentos? buscarPorCodigo(String codigo) {
    final c = codigo.trim();
    for (final p in estado.produtos) {
      if (p.codigo == c) return p;
    }
    return null;
  }
}
