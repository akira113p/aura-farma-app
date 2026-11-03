// O QUE É ESTE ARQUIVO
// O "cérebro" do app: o AppStore guarda login, dados da farmácia e tema, e oferece as ações
// (entrar, sair, recarregar, solicitações, contagem...). Quem usa: main.dart (cria), todas as telas
// (via state/app_scope.dart). Usa: core/api_client.dart (rede) e models.dart (tipos de dado).
// Veja GUIA_FLUTTER.md → Estado compartilhado: ChangeNotifier.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../models.dart';

/// Em que ponto está o login. `enum` = lista fechada de valores possíveis.
/// carregando: ainda checando se há sessão salva (mostra a splash);
/// deslogado: precisa fazer login; logado: sessão válida (mostra o app).
enum StatusAuth { carregando, deslogado, logado }

/// Estado global do app: sessão, dados da farmácia e tema.
///
/// É um ChangeNotifier: guarda dados e, quando eles mudam, chama `notifyListeners()` para
/// avisar quem está "escutando" (as telas), que então se redesenham. Fluxo típico: o usuário
/// toca num botão -> a tela chama um método daqui -> ele fala com a API -> atualiza os campos
/// -> `notifyListeners()`. Veja GUIA_FLUTTER.md → Estado compartilhado.
class AppStore extends ChangeNotifier {
  /// `api` opcional: nos testes se injeta um ApiClient falso; no app real cria o padrão.
  AppStore({ApiClient? api}) : api = api ?? ApiClient();

  /// Cliente HTTP usado para falar com o backend.
  final ApiClient api;

  /// Chave sob a qual o tema (claro/escuro) é salvo no aparelho.
  static const _chaveTema = 'aurafarma.tema';

  /// Situação do login. Começa `carregando` até `iniciar` descobrir se há sessão.
  StatusAuth status = StatusAuth.carregando;
  /// Usuário logado (nulo = ninguém logado).
  Usuario? usuario;
  /// Dados da farmácia (produtos, solicitações, contagens) vindos da API.
  Estado estado = Estado.vazio;
  /// true enquanto `recarregar` busca os dados (as telas podem mostrar um indicador).
  bool carregandoEstado = false;
  /// Mensagem de erro da última carga de dados; nulo = sem erro.
  String? erroEstado;
  /// Tema atual (claro ou escuro). Lido pelo MaterialApp em main.dart.
  ThemeMode tema = ThemeMode.light;

  /// Carrega tema + cookie salvo -> /auth/me -> estado.
  // Chamado uma vez, no initState do MainApp. Passos: (1) ler o tema salvo; (2) carregar o
  // cookie guardado; (3) se há cookie, perguntar ao servidor quem é o usuário; (4) carregar os dados.
  Future<void> iniciar() async {
    try {
      // (1) Lê o tema do "caderninho" do aparelho. Falha aqui é ignorada (fica o tema claro).
      final prefs = await SharedPreferences.getInstance();
      tema = prefs.getString(_chaveTema) == 'escuro'
          ? ThemeMode.dark
          : ThemeMode.light;
    } catch (_) {}
    // (2) Traz o cookie salvo para a memória do ApiClient.
    await api.carregarSessao();
    // Sem cookie: não há o que validar, vai direto para o login.
    if (!api.temSessao) {
      status = StatusAuth.deslogado;
      notifyListeners();
      return;
    }
    try {
      // (3) Pergunta ao servidor quem está logado. Se o cookie expirou, vem erro 401.
      final r = await api.get('/auth/me');
      // Converte o JSON do usuário em objeto Usuario (`as Map` confere o tipo).
      usuario = Usuario.fromJson(Map<String, dynamic>.from(r['user'] as Map));
      status = StatusAuth.logado;
      notifyListeners();
      // (4) Busca produtos etc. Já com `status = logado`, o app abre enquanto os dados carregam.
      await recarregar();
    // `on ApiException` captura só erros da API. 401 = sessão inválida: apaga o cookie.
    } on ApiException catch (e) {
      if (e.status == 401) await api.limparSessao();
      // Sem conexão: sem como validar a sessão, cai no login (cookie fica salvo).
      status = StatusAuth.deslogado;
      notifyListeners();
    }
  }

  /// Lança [ApiException] em caso de erro.
  // Chamado pela tela de login ao tocar em "Entrar". Recebe e-mail/usuário e senha.
  // Em caso de sucesso guarda o usuário e carrega os dados; o cookie é guardado pelo ApiClient.
  Future<void> entrar(String identificador, String senha) async {
    // Pede o login ao servidor. Erro (senha errada, sem rede) sobe para quem chamou tratar.
    final r = await api.post(
        '/auth/login', {'identifier': identificador, 'password': senha});
    usuario = Usuario.fromJson(Map<String, dynamic>.from(r['user'] as Map));
    // Zera dados de uma sessão anterior para não mostrar produtos de outra conta.
    estado = Estado.vazio;
    erroEstado = null;
    status = StatusAuth.logado;
    notifyListeners();
    await recarregar();
  }

  /// Logout. Chamado quando o usuário toca em "sair". Tenta avisar o servidor, mas mesmo
  /// que falhe (sem internet) desloga localmente, para o usuário nunca ficar preso.
  Future<void> sair() async {
    try {
      await api.post('/auth/logout');
    } catch (_) {}
    await _deslogarLocal();
  }

  /// Limpa tudo do lado do app: cookie, usuário e dados, e volta o status para `deslogado`.
  /// O AuthGate percebe a mudança e mostra a tela de login.
  Future<void> _deslogarLocal() async {
    await api.limparSessao();
    usuario = null;
    estado = Estado.vazio;
    erroEstado = null;
    status = StatusAuth.deslogado;
    notifyListeners();
  }

  /// Executa uma ação da API; 401 desloga localmente e relança.
  // `<T>` = tipo genérico: devolve o mesmo tipo que `acao` devolver. `acao` é uma função
  // passada de fora. Se o servidor responder 401 (sessão caiu), desloga e relança o erro
  // (`rethrow`) para a tela que chamou também saber.
  Future<T> _proteger<T>(Future<T> Function() acao) async {
    try {
      return await acao();
    } on ApiException catch (e) {
      if (e.status == 401) await _deslogarLocal();
      rethrow;
    }
  }

  /// Busca todos os dados da farmácia (`/estado`). Chamada após login e quando a tela pede
  /// atualização. Erros viram texto em `erroEstado` em vez de estourar.
  Future<void> recarregar() async {
    // Liga o "carregando" e avisa as telas já (notifyListeners) para mostrarem o indicador.
    carregandoEstado = true;
    erroEstado = null;
    notifyListeners();
    try {
      // `() => ...` é uma função sem nome passada ao _proteger.
      final r = await _proteger(() => api.get('/estado'));
      estado = Estado.fromJson(Map<String, dynamic>.from(r as Map));
    } on ApiException catch (e) {
      erroEstado = e.message;
    // Qualquer outro erro inesperado (ex.: JSON inesperado).
    } catch (_) {
      erroEstado = 'Não foi possível carregar os dados.';
    }
    carregandoEstado = false;
    notifyListeners();
  }

  /// Pede ao servidor para preencher a conta com produtos de exemplo e guarda o novo estado.
  Future<void> popularExemplo() async {
    final r = await _proteger(() => api.post('/estado/seed'));
    estado = Estado.fromJson(Map<String, dynamic>.from(r as Map));
    notifyListeners();
  }

  /// Troca claro <-> escuro. Chamada pelo botão de tema. Atualiza a tela na hora e salva a
  /// escolha no aparelho sem esperar (por isso `.then`, e não `await`).
  void alternarTema() {
    tema = tema == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    // Gravação em segundo plano; `.catchError` ignora falhas de disco.
    SharedPreferences.getInstance().then((p) {
      p.setString(_chaveTema, tema == ThemeMode.dark ? 'escuro' : 'claro');
    }).catchError((_) {});
  }

  // ------------------------------------------------------------ solicitados

  /// Cria uma solicitação (produto pedido por clientes). Recebe nome e observação.
  /// Se a API devolver uma que já existe (mesmo id), substitui; senão acrescenta.
  Future<void> registrarSolicitacao(String nome, String nota) async {
    final r = await _proteger(
        () => api.post('/solicitados', {'name': nome, 'note': nota}));
    final nova =
        Solicitacao.fromJson(Map<String, dynamic>.from(r['request'] as Map));
    // Copia a lista (`...` espalha os itens) para não alterar a original; `copyWith` abaixo cria novo Estado.
    final lista = [...estado.solicitacoes];
    // Posição da solicitação com o mesmo id, ou -1 se for nova.
    final i = lista.indexWhere((s) => s.id == nova.id);
    if (i >= 0) {
      lista[i] = nova;
    } else {
      lista.add(nova);
    }
    estado = estado.copyWith(solicitacoes: lista);
    notifyListeners();
  }

  /// Soma +1 no contador de pedidos de uma solicitação (PATCH). Troca a antiga pela versão do servidor.
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

  /// Apaga a solicitação de id [id] no servidor e a tira da lista local (`where` mantém só as de id diferente).
  Future<void> removerSolicitacao(String id) async {
    await _proteger(() => api.delete('/solicitados/$id'));
    estado = estado.copyWith(
      solicitacoes: estado.solicitacoes.where((x) => x.id != id).toList(),
    );
    notifyListeners();
  }

  // --------------------------------------------------------------- contagem

  /// [novoEstoquePorPid]: id do produto -> estoque contado.
  // Envia a contagem de estoque. O servidor ajusta o estoque, registra a contagem e devolve os
  // produtos atualizados, que substituem os antigos no estado local.
  Future<void> aplicarContagem(Map<String, int> novoEstoquePorPid) async {
    // Transforma o mapa {idProduto: quantidade} numa lista no formato que a API espera.
    final ajustes = novoEstoquePorPid.entries
        .map((e) => {'pid': e.key, 'newStock': e.value})
        .toList();
    final r = await _proteger(
        () => api.post('/contagem', {'adjustments': ajustes}));
    final contagem =
        Contagem.fromJson(Map<String, dynamic>.from(r['count'] as Map));
    // Mapa id -> produto atualizado. `?? const []` evita erro se a chave vier ausente (nula).
    final atualizados = {
      for (final p in (r['updatedProducts'] as List? ?? const []))
        Medicamentos.fromJson(Map<String, dynamic>.from(p as Map)).id:
            Medicamentos.fromJson(Map<String, dynamic>.from(p)),
    };
    estado = estado.copyWith(
      // Para cada produto: usa a versão atualizada se existir; senão mantém o atual (`??`).
      produtos: estado.produtos.map((p) => atualizados[p.id] ?? p).toList(),
      // Nova contagem entra no começo da lista (mais recente primeiro).
      contagens: [contagem, ...estado.contagens],
    );
    notifyListeners();
  }

  // ---------------------------------------------------------------- scanner

  /// Procura um produto pelo código de barras/SKU (usado pelo scanner). Devolve o produto
  /// ou null se não achar. `trim` tira espaços que o leitor possa ter incluído.
  Medicamentos? buscarPorCodigo(String codigo) {
    final c = codigo.trim();
    for (final p in estado.produtos) {
      if (p.codigo == c) return p;
    }
    return null;
  }
}
