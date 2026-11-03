// O QUE É ESTE ARQUIVO: a tela "Assistente IA" (um chat). O usuário pergunta sobre a
// farmácia (estoque, vendas, pedidos...) e o servidor responde usando uma IA que consulta
// os dados dele. Ela é uma das abas do app (fica num IndexedStack, por isso continua
// "viva" mesmo quando outra aba está visível).
// Usa: `conversa.dart` (modelos + histórico salvo no celular), `texto_formatado.dart`
// (desenha negrito/listas/tabelas), `AppScope` (acesso ao usuário e à API) e `app_theme.dart` (cores).
// (veja GUIA_FLUTTER.md → IndexedStack, StatefulWidget)
import 'package:flutter/material.dart';

import 'core/api_client.dart';
import 'ia/conversa.dart';
import 'ia/texto_formatado.dart';
import 'state/app_scope.dart';
import 'theme/app_theme.dart';
import 'widgets/cabecalho.dart';
import 'widgets/cartao.dart';
import 'widgets/icones.dart';

// [ESCRITO À MÃO] Nomes TelaAssistente/_TelaAssistente, StatefulWidget e Scaffold preservados.
// TelaAssistente é um StatefulWidget: precisa lembrar de coisas que mudam (texto digitado,
// conversa aberta, "pensando..."). São sempre duas classes: esta (só a "casca", imutável)
// e a `_TelaAssistente` abaixo (o State, onde ficam as variáveis que mudam).
class TelaAssistente extends StatefulWidget {
  const TelaAssistente({super.key});

  @override
  State<TelaAssistente> createState() => _TelaAssistente();
}
// [FIM ESCRITO À MÃO]

/// O State da tela: guarda tudo o que muda e contém a lógica do chat.
/// (veja GUIA_FLUTTER.md → setState e ciclo de vida do State)
class _TelaAssistente extends State<TelaAssistente> {
  // _campo = controle remoto do campo de texto onde o usuário digita a pergunta (lê e limpa o texto).
  final _campo = TextEditingController();
  // _foco = controla/observa o foco (se o cursor está no campo de pergunta).
  final _foco = FocusNode();
  // _rolagem = controla a rolagem da lista de mensagens (usado para rolar até o fim).
  final _rolagem = ScrollController();

  // _userId = id do usuário dono do histórico carregado; serve para detectar troca de conta.
  String? _userId; // dono do histórico carregado
  // _iaAtiva = false quando o servidor avisa que a IA está desligada (então o envio é bloqueado).
  bool _iaAtiva = true;
  // _pensando = true entre enviar a pergunta e chegar a resposta (mostra "pensando…" e trava novo envio).
  bool _pensando = false;
  // _configIniciada = garante que a consulta de configuração da IA seja feita só uma vez.
  bool _configIniciada = false;
  // _historico = todas as conversas salvas, da mais recente para a mais antiga.
  List<ConversaIA> _historico = [];
  ConversaIA? _atual; // null = nenhuma conversa aberta

  /// Roda UMA vez quando a tela nasce. Aqui avisa a tela para se redesenhar sempre que o
  /// texto do campo mudar: assim o botão "Enviar" aparece/some conforme há texto digitado.
  @override
  void initState() {
    super.initState();
    _campo.addListener(() => setState(() {}));
  }

  /// Roda depois do initState e de novo quando algo de que a tela depende muda (aqui: o
  /// usuário logado, lido via AppScope). Faz duas coisas: (1) na primeira vez, consulta se a
  /// IA está ativa; (2) se o usuário mudou, zera a conversa e recarrega o histórico dele.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // (1) Só na primeira passada: a flag impede repetir a consulta ao servidor.
    if (!_configIniciada) {
      _configIniciada = true;
      _carregarConfig();
    }
    // (2) A tela vive num IndexedStack: se o usuário mudou (logout/login), recarrega.
    // `AppScope.of(context)` lê o estado global E faz esta tela reagir às mudanças dele.
    // `usuario?.id` usa `?.`: se não houver usuário logado, o resultado é nulo em vez de erro.
    // A tela vive num IndexedStack: se o usuário mudou (logout/login), recarrega.
    final id = AppScope.of(context).usuario?.id;
    if (id != _userId) {
      _userId = id;
      _atual = null;
      _historico = [];
      _pensando = false;
      if (id != null) _carregarHistorico(id);
    }
  }

  /// Roda UMA vez quando a tela morre. Libera os controllers (senão ficariam ocupando
  /// memória). Sempre chame `super.dispose()` por último.
  @override
  void dispose() {
    _campo.dispose();
    _foco.dispose();
    _rolagem.dispose();
    super.dispose();
  }

  /// Pergunta ao servidor (GET /ia/config) se a IA está ativa e guarda em `_iaAtiva`.
  /// Chamada uma vez, pelo didChangeDependencies. É `Future<void>`: roda de forma assíncrona e não devolve valor.
  Future<void> _carregarConfig() async {
    // `read` (e não `of`): só quero a API agora, sem fazer a tela reagir a mudanças.
    final api = AppScope.read(context).api;
    try {
      // `await` espera a resposta sem travar a tela. `r is Map ? ... : true` confere o formato:
      // só marca como desativada se vier `enabled: false` explicitamente.
      final r = await api.get('/ia/config');
      final ativo = r is Map ? r['enabled'] != false : true;
      // `mounted`: depois do await a tela pode já ter sido fechada; só mexe no estado se ainda existir.
      if (mounted) setState(() => _iaAtiva = ativo);
    } catch (_) {
      // Sem resposta: assume ativa; o envio mostra o erro real.
    }
  }

  /// Carrega do celular o histórico do usuário [id] e mostra na tela.
  /// Chamada quando a tela descobre qual é o usuário (didChangeDependencies).
  Future<void> _carregarHistorico(String id) async {
    final lista = await HistoricoIA.carregar(id);
    // Depois do await, confere duas coisas: a tela ainda existe e o usuário continua o mesmo
    // (ele pode ter trocado de conta enquanto o histórico carregava; aí descarta o resultado).
    if (!mounted || id != _userId) return;
    setState(() => _historico = lista);
  }

  /// Rola a lista de mensagens até o final, com animação de 200 ms.
  /// Por que `addPostFrameCallback`: a nova mensagem só entra na lista DEPOIS do próximo
  /// frame (desenho da tela); se rolasse antes, pararia na posição antiga. `hasClients` confere
  /// se a lista já está na tela.
  void _rolarAoFim() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_rolagem.hasClients) return;
      _rolagem.animateTo(
        _rolagem.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  /// Volta para a tela inicial do chat (sem conversa aberta). Chamada ao tocar no botão
  /// "Nova conversa" do cabeçalho. Ignora o toque enquanto a IA está respondendo.
  void _novaConversa() {
    if (_pensando) return;
    setState(() => _atual = null);
  }

  /// Abre uma conversa do histórico [c] e rola até a última mensagem. Chamada ao tocar num item do histórico.
  void _abrir(ConversaIA c) {
    if (_pensando) return;
    setState(() => _atual = c);
    _rolarAoFim();
  }

  /// Remove a versão antiga (mesmo id), põe a conversa na frente, corta o excesso (máx. 30)
  /// e salva no celular. O `HistoricoIA.salvar` não tem `await` de propósito: salvar é
  /// "dispare e esqueça", a tela não precisa esperar.
  /// Insere/atualiza a conversa no topo do histórico e persiste.
  void _persistir(ConversaIA c) {
    c.atualizadoEm = DateTime.now().millisecondsSinceEpoch;
    _historico.removeWhere((x) => x.id == c.id);
    _historico.insert(0, c);
    if (_historico.length > maxConversas) {
      _historico = _historico.sublist(0, maxConversas);
    }
    final id = _userId;
    if (id != null) HistoricoIA.salvar(id, _historico);
  }

  /// Envia a pergunta digitada para a IA e mostra a resposta. Chamada ao tocar em "Enviar"
  /// ou no "enviar" do teclado. É o coração da tela.
  /// Passos: (1) valida; (2) adiciona a pergunta na conversa; (3) chama o servidor;
  /// (4) transforma o resultado (ou o erro) em uma mensagem; (5) salva e atualiza a tela.
  Future<void> _enviar() async {
    // (1) Pega o texto sem espaços nas pontas e desiste se estiver vazio, se já há uma resposta
    // em andamento, ou se a IA estiver desativada.
    final pergunta = _campo.text.trim();
    if (pergunta.isEmpty || _pensando || !_iaAtiva) return;
    final id = _userId;
    final api = AppScope.read(context).api;

    // (2) É a primeira pergunta de uma conversa nova? (`_atual == null`). Se sim, cria uma
    // ConversaIA com título provisório (a pergunta cortada); se não, continua a atual (`??`).
    final primeira = _atual == null;
    final conversa = _atual ??
        ConversaIA(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          titulo: tituloDaPergunta(pergunta),
        );
    // Adiciona a pergunta como mensagem do usuário, cortando em 4000 caracteres se passar do limite.
    conversa.mensagens.add(MensagemIA(
        'user',
        pergunta.length > maxCaracteres
            ? pergunta.substring(0, maxCaracteres)
            : pergunta));
    // `setState` avisa o Flutter que algo mudou e a tela deve ser redesenhada: mostra a conversa,
    // liga o "pensando…" e limpa o campo de texto.
    setState(() {
      _atual = conversa;
      _pensando = true;
      _campo.clear();
    });
    _rolarAoFim();

    // (3) `resposta` será preenchida em um dos três caminhos abaixo (sucesso, erro da API, outro erro).
    MensagemIA resposta;
    // try/catch: se algo der errado na chamada, caímos nos `catch` em vez de travar o app.
    try {
      // POST em /ia/ask mandando as mensagens (filtradas por `paraEnvio`) e o escopo. O terceiro
      // argumento é o tempo máximo de espera (60 s), pois a IA pode demorar.
      final r = await api.post(
        '/ia/ask',
        {'messages': conversa.paraEnvio(), 'escopo': 'todos'},
        const Duration(seconds: 60),
      );
      // A resposta do servidor deve ser um Map; se não for, usa um Map vazio.
      // `'${m['reply'] ?? ''}'` transforma em texto e troca nulo por vazio.
      final m = r is Map ? r : const {};
      final texto = '${m['reply'] ?? ''}'.trim();
      // Resposta vazia vira uma mensagem de erro amigável ("A IA não retornou resposta.").
      resposta = MensagemIA(
          'assistant', texto.isEmpty ? 'A IA não retornou resposta.' : texto,
          erro: texto.isEmpty);
      // O servidor pode sugerir um título melhor; só usamos na primeira pergunta da conversa.
      final titulo = '${m['titulo'] ?? ''}'.trim();
      if (primeira && titulo.isNotEmpty) conversa.titulo = titulo;
    // ApiException = erro conhecido da API (ex.: sem permissão, limite excedido): mostra a mensagem dele.
    } on ApiException catch (e) {
      resposta = MensagemIA('assistant', e.message, erro: true);
    // Qualquer outro erro (sem internet, tempo esgotado...) vira uma mensagem genérica.
    } catch (_) {
      resposta = const MensagemIA(
          'assistant', 'Não foi possível consultar a IA.',
          erro: true);
    }

    // (4) Guarda a resposta na conversa.
    conversa.mensagens.add(resposta);
    // Caso especial: se o usuário trocou de conta (ou a tela fechou) durante a espera, NÃO mexemos
    // na tela. Salvamos a conversa direto no histórico do dono original e terminamos.
    if (id != null && (!mounted || id != _userId)) {
      // Usuário trocou durante a espera: salva no dono original, sem mexer na tela.
      final lista = await HistoricoIA.carregar(id);
      lista.removeWhere((x) => x.id == conversa.id);
      lista.insert(0, conversa);
      await HistoricoIA.salvar(id, lista);
      return;
    }
    // (5) Fluxo normal: se a tela fechou, nada a fazer; senão salva, desliga o "pensando…" e rola para o fim.
    if (!mounted) return;
    _persistir(conversa);
    setState(() => _pensando = false);
    _rolarAoFim();
  }

  /// Desenha a tela inteira. Chamado pelo Flutter toda vez que algo muda (setState, tema...).
  /// Estrutura: Scaffold (esqueleto) > SafeArea (evita notch/barra de status) > Column com
  /// o Cabecalho em cima e, embaixo, a conversa ou a tela inicial.
  @override
  Widget build(BuildContext context) {
    // `c` = paleta de cores do tema atual (claro/escuro).
    final c = AppCores.of(context);
    // emConversa = true quando há uma conversa aberta (muda o que a tela mostra).
    final emConversa = _atual != null;

    // [ESCRITO À MÃO] O AppBar(title: "Assistente de ia") virou o Cabecalho do Figma
    // dentro do body; Scaffold e Column do esqueleto foram mantidos.
    return Scaffold(
      backgroundColor: c.fundo,
      body: SafeArea(
        child: Column(
          children: [
            Cabecalho(
              titulo: 'Assistente IA',
              subtitulo: 'Perguntas sobre a farmácia',
              descricao: 'Pergunte o que quiser - eu consulto seus dados!',
              acoes: [
                // Botão "Nova conversa" só aparece quando há conversa aberta (`if` dentro da lista).
                // `onPressed: null` desabilita o botão enquanto a IA responde.
                if (emConversa)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Nova conversa',
                    icon: Icon(Icons.add_comment_outlined,
                        color: c.textoSuave, size: 22),
                    onPressed: _pensando ? null : _novaConversa,
                  ),
              ],
            ),
            // `...[ ]` (spread) insere vários widgets na lista. `Expanded` ocupa todo o espaço que sobrar
            // na Column. Com conversa: lista de mensagens + barra de digitação. Sem conversa: tela
            // inicial centralizada + cartão com o histórico.
            if (emConversa) ...[
              Expanded(child: _listaMensagens(c)),
              _barraCampo(c),
            ] else ...[
              Expanded(child: _telaVazia(c)),
              _cartaoHistorico(c),
            ],
          ],
        ),
      ),
    );
    // [FIM ESCRITO À MÃO]
  }

  /// Tela inicial (sem conversa): título, subtítulo e o campo de pergunta, centralizados.
  /// SingleChildScrollView evita estouro quando o teclado ocupa espaço.
  Widget _telaVazia(AppCores c) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Em que posso ajudar na farmácia?',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: c.texto)),
            const SizedBox(height: 6),
            Text('Pergunte o que quiser - eu consulto seus dados!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: c.textoSuave)),
            const SizedBox(height: 18),
            _campoPergunta(c),
            if (!_iaAtiva) _aviso(c),
          ],
        ),
      ),
    );
  }

  /// Aviso vermelho "IA desativada no servidor." mostrado abaixo do campo quando `_iaAtiva` é falso.
  /// Sintaxe `=>` devolve o widget direto, sem chaves nem `return`.
  Widget _aviso(AppCores c) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text('IA desativada no servidor.',
            style: TextStyle(fontSize: 12, color: c.perigo)),
      );

  /// O campo onde se digita a pergunta, com ícone de lupa e botão de enviar.
  /// Usado tanto na tela inicial quanto na barra de baixo durante a conversa.
  Widget _campoPergunta(AppCores c) {
    // habilitado = pode enviar agora (IA ativa e sem resposta em andamento).
    final habilitado = _iaAtiva && !_pensando;
    // temTexto = há algo digitado? Só então mostramos o botão de enviar (por isso o initState
    // redesenha a tela a cada letra digitada).
    final temTexto = _campo.text.trim().isNotEmpty;
    // Figma: campo de pergunta transparente (cinza do fundo) com borda fina
    // Container com `Colors.transparent` e borda fina: deixa ver o cinza do fundo (visual do Figma).
    // Row = coloca lupa, campo e botão lado a lado; Expanded faz o campo ocupar o espaço restante.
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.borda),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          ico(Ico.busca, size: 22, color: c.textoSuave),
          Expanded(
            // TextField: o campo de texto. `minLines/maxLines` deixam ele crescer de 1 até 4 linhas;
            // `maxLength` limita a 4000 caracteres (o contador é escondido com `counterText: ''`);
            // `onSubmitted` é chamado quando o usuário aperta "enviar" no teclado.
            child: TextField(
              controller: _campo,
              focusNode: _foco,
              enabled: _iaAtiva,
              minLines: 1,
              maxLines: 4,
              maxLength: maxCaracteres,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _enviar(),
              style: TextStyle(fontSize: 14, color: c.texto),
              decoration: InputDecoration(
                hintText: 'Pergunte sobre estoque, vendas, pedidos...',
                hintStyle: TextStyle(fontSize: 14, color: c.textoFraco),
                counterText: '',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                filled: false,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
              ),
            ),
          ),
          // Botão enviar (cor laranja quando habilitado, cinza quando não); sem texto, só um espaço de 8.
          if (temTexto)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Enviar',
              icon: ico(Ico.enviar,
                  size: 20, color: habilitado ? c.destaque : c.textoFraco),
              onPressed: habilitado ? _enviar : null,
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }

  /// Barra de baixo durante a conversa: o campo de pergunta (e o aviso de IA desativada) com margens.
  Widget _barraCampo(AppCores c) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _campoPergunta(c),
            if (!_iaAtiva) _aviso(c),
          ],
        ),
      );

  /// A lista rolável de mensagens da conversa aberta. `ListView.builder` só constrói as bolhas
  /// visíveis na tela (eficiente para conversas longas). O "+ 1" abre espaço para a bolha
  /// "pensando…" no final enquanto aguardamos a resposta.
  Widget _listaMensagens(AppCores c) {
    // `_atual!` = tenho certeza de que há conversa aberta (esta função só é chamada nesse caso).
    final msgs = _atual!.mensagens;
    return ListView.builder(
      controller: _rolagem,
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 8),
      itemCount: msgs.length + (_pensando ? 1 : 0),
      itemBuilder: (_, i) =>
          i == msgs.length ? _bolhaPensando(c) : _bolha(c, msgs[i]),
    );
  }

  /// Desenha UMA bolha de mensagem [m]. Cores: erro = vermelho claro; usuário = laranja
  /// clarinho (à direita); IA = cor de superfície com borda (à esquerda).
  Widget _bolha(AppCores c, MensagemIA m) {
    final usuario = m.doUsuario;
    final cor = m.erro
        ? c.perigo.withValues(alpha: 0.1)
        : usuario
            ? c.destaqueSuave
            : c.superficie;
    final estilo = TextStyle(
      fontSize: 14,
      height: 1.35,
      // c.texto nos dois casos: destaqueSuave é claro no tema claro e escuro no escuro.
      color: m.erro ? c.perigo : c.texto,
    );
    // Align encosta a bolha à direita (usuário) ou à esquerda (IA). `maxWidth` de 82% da largura
    // da tela (MediaQuery) impede que bolhas muito largas ocupem tudo.
    return Align(
      alignment: usuario ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.82),
        decoration: BoxDecoration(
          color: cor,
          borderRadius: BorderRadius.circular(12),
          border:
              usuario ? null : Border.all(color: m.erro ? c.perigo : c.borda),
        ),
        // Mensagens do usuário e de erro são texto puro; só a resposta da IA passa pelo
        // TextoFormatado (negrito, listas, tabelas).
        child: usuario || m.erro
            ? Text(m.content, style: estilo)
            : TextoFormatado(m.content, estilo: estilo),
      ),
    );
  }

  /// A bolha provisória "pensando…" (itálico) mostrada enquanto a resposta não chega.
  Widget _bolhaPensando(AppCores c) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: c.superficie,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.borda),
          ),
          child: Text('pensando…',
              style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: c.textoSuave)),
        ),
      );

  /// Cartão "Histórico" da tela inicial: lista as conversas salvas; tocar em uma abre a conversa.
  /// Se não há nenhuma, mostra "Suas perguntas aparecem aqui."; a lista tem altura máxima de 180.
  Widget _cartaoHistorico(AppCores c) {
    final n = _historico.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 12),
      child: CartaoComFaixa(
        titulo: 'Histórico',
        contador: '$n pergunta(s)',
        child: n == 0
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Suas perguntas aparecem aqui.',
                    style: TextStyle(fontSize: 13, color: c.textoSuave)),
              )
            : ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                // ListView.separated = lista com divisória entre itens; `shrinkWrap: true` faz ela ocupar só o
                // necessário (precisa disso porque está dentro de uma caixa de altura limitada).
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: n,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: c.borda.withValues(alpha: 0.4)),
                  itemBuilder: (_, i) {
                    final h = _historico[i];
                    return InkWell(
                      onTap: () => _abrir(h),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 11),
                        child: Row(
                          children: [
                            Icon(Icons.chat_bubble_outline,
                                size: 16, color: c.textoSuave),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                h.titulo.isEmpty ? 'Conversa' : h.titulo,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 13, color: c.texto),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
