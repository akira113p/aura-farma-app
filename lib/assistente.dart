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
class TelaAssistente extends StatefulWidget {
  const TelaAssistente({super.key});

  @override
  State<TelaAssistente> createState() => _TelaAssistente();
}
// [FIM ESCRITO À MÃO]

class _TelaAssistente extends State<TelaAssistente> {
  final _campo = TextEditingController();
  final _foco = FocusNode();
  final _rolagem = ScrollController();

  String? _userId; // dono do histórico carregado
  bool _iaAtiva = true;
  bool _pensando = false;
  bool _configIniciada = false;
  List<ConversaIA> _historico = [];
  ConversaIA? _atual; // null = nenhuma conversa aberta

  @override
  void initState() {
    super.initState();
    _campo.addListener(() => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_configIniciada) {
      _configIniciada = true;
      _carregarConfig();
    }
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

  @override
  void dispose() {
    _campo.dispose();
    _foco.dispose();
    _rolagem.dispose();
    super.dispose();
  }

  Future<void> _carregarConfig() async {
    final api = AppScope.read(context).api;
    try {
      final r = await api.get('/ia/config');
      final ativo = r is Map ? r['enabled'] != false : true;
      if (mounted) setState(() => _iaAtiva = ativo);
    } catch (_) {
      // Sem resposta: assume ativa; o envio mostra o erro real.
    }
  }

  Future<void> _carregarHistorico(String id) async {
    final lista = await HistoricoIA.carregar(id);
    if (!mounted || id != _userId) return;
    setState(() => _historico = lista);
  }

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

  void _novaConversa() {
    if (_pensando) return;
    setState(() => _atual = null);
  }

  void _abrir(ConversaIA c) {
    if (_pensando) return;
    setState(() => _atual = c);
    _rolarAoFim();
  }

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

  Future<void> _enviar() async {
    final pergunta = _campo.text.trim();
    if (pergunta.isEmpty || _pensando || !_iaAtiva) return;
    final id = _userId;
    final api = AppScope.read(context).api;

    final primeira = _atual == null;
    final conversa = _atual ??
        ConversaIA(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          titulo: tituloDaPergunta(pergunta),
        );
    conversa.mensagens.add(MensagemIA(
        'user',
        pergunta.length > maxCaracteres
            ? pergunta.substring(0, maxCaracteres)
            : pergunta));
    setState(() {
      _atual = conversa;
      _pensando = true;
      _campo.clear();
    });
    _rolarAoFim();

    MensagemIA resposta;
    try {
      final r = await api.post(
        '/ia/ask',
        {'messages': conversa.paraEnvio(), 'escopo': 'todos'},
        const Duration(seconds: 60),
      );
      final m = r is Map ? r : const {};
      final texto = '${m['reply'] ?? ''}'.trim();
      resposta = MensagemIA(
          'assistant', texto.isEmpty ? 'A IA não retornou resposta.' : texto,
          erro: texto.isEmpty);
      final titulo = '${m['titulo'] ?? ''}'.trim();
      if (primeira && titulo.isNotEmpty) conversa.titulo = titulo;
    } on ApiException catch (e) {
      resposta = MensagemIA('assistant', e.message, erro: true);
    } catch (_) {
      resposta = const MensagemIA(
          'assistant', 'Não foi possível consultar a IA.',
          erro: true);
    }

    conversa.mensagens.add(resposta);
    if (id != null && (!mounted || id != _userId)) {
      // Usuário trocou durante a espera: salva no dono original, sem mexer na tela.
      final lista = await HistoricoIA.carregar(id);
      lista.removeWhere((x) => x.id == conversa.id);
      lista.insert(0, conversa);
      await HistoricoIA.salvar(id, lista);
      return;
    }
    if (!mounted) return;
    _persistir(conversa);
    setState(() => _pensando = false);
    _rolarAoFim();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppCores.of(context);
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

  Widget _aviso(AppCores c) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text('IA desativada no servidor.',
            style: TextStyle(fontSize: 12, color: c.perigo)),
      );

  Widget _campoPergunta(AppCores c) {
    final habilitado = _iaAtiva && !_pensando;
    final temTexto = _campo.text.trim().isNotEmpty;
    // Figma: campo de pergunta transparente (cinza do fundo) com borda fina
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

  Widget _listaMensagens(AppCores c) {
    final msgs = _atual!.mensagens;
    return ListView.builder(
      controller: _rolagem,
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 8),
      itemCount: msgs.length + (_pensando ? 1 : 0),
      itemBuilder: (_, i) =>
          i == msgs.length ? _bolhaPensando(c) : _bolha(c, msgs[i]),
    );
  }

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
        child: usuario || m.erro
            ? Text(m.content, style: estilo)
            : TextoFormatado(m.content, estilo: estilo),
      ),
    );
  }

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
