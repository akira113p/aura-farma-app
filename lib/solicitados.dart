// O QUE É ESTE ARQUIVO
// A tela "Solicitados": lista os produtos que clientes pediram e a farmácia NÃO tinha
// em estoque, com a contagem de quantos pedidos cada um teve. Dá para somar +1 pedido,
// deslizar o item para remover e registrar uma nova solicitação (botão "+" flutuante,
// que abre um formulário de baixo da tela).
// É uma aba principal do app. Usa o estado global (state/app_scope.dart), o modelo
// `Solicitacao` (models.dart) e os widgets prontos de widgets/.
import 'package:flutter/material.dart';

import 'core/api_client.dart';
import 'models.dart';
import 'state/app_scope.dart';
import 'theme/app_theme.dart';
import 'widgets/cabecalho.dart';
import 'widgets/cartao.dart';
import 'widgets/icones.dart';

// [ESCRITO À MÃO] esqueleto original: TelaSolicitados (StatefulWidget) + _TelaSolicitados com Scaffold.
// Mantidos os nomes das classes; o AppBar(title: "Solicitados") foi trocado pelo Cabecalho do Figma,
// o Column vazio do body virou o conteúdo da tela e foi adicionado o FAB de registro.
/// A tela de solicitados. É um StatefulWidget: precisa lembrar de coisas que mudam
/// (quais itens estão sendo atualizados no momento). A memória fica em `_TelaSolicitados`.
/// (veja GUIA_FLUTTER.md → StatefulWidget)
class TelaSolicitados extends StatefulWidget {
  const TelaSolicitados({super.key});

  /// O Flutter chama isto uma vez para criar a "memória" (State) da tela.
  @override
  State<TelaSolicitados> createState() => _TelaSolicitados();
}

/// Memória e desenho da tela de solicitados (o `_` = privada a este arquivo).
class _TelaSolicitados extends State<TelaSolicitados> {
  // [FIM ESCRITO À MÃO]

  /// ids com requisição em andamento (evita duplo envio).
  /// É um Set (conjunto sem repetidos): se o id está aqui, o botão "+1" daquele item fica travado.
  final Set<String> _ocupados = {};

  /// Mostra a mensagem de erro [e] num aviso rápido (SnackBar) embaixo da tela.
  /// Chamada sempre que uma ação falha com erro da API.
  void _erro(ApiException e) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
  }

  /// Soma +1 pedido à solicitação [s]. Chamada quando o usuário toca no "+1".
  /// Marca o item como ocupado durante a chamada ao servidor, para o usuário não
  /// tocar duas vezes seguidas e contar em dobro. `async` porque fala com o servidor.
  Future<void> _somar(Solicitacao s) async {
    // Se já há uma requisição em andamento para este item, ignora o toque.
    if (_ocupados.contains(s.id)) return;
    final store = AppScope.read(context);
    // Marca como ocupado e redesenha (o botão vira uma rodinha).
    setState(() => _ocupados.add(s.id));
    try {
      await store.somarSolicitacao(s);
    } on ApiException catch (e) {
      // `mounted`: depois do await a tela pode ter sido fechada; só usa `context` se ainda existe.
      if (mounted) _erro(e);
    } finally {
      // Roda sempre (deu certo ou não): destrava o botão.
      if (mounted) setState(() => _ocupados.remove(s.id));
    }
  }

  /// Pergunta "Remover solicitação?" e, se o usuário confirmar, remove no servidor.
  /// Chamada quando o usuário desliza um item para o lado (veja o `Dismissible` em `_item`).
  /// Devolve SEMPRE `false` (veja o comentário dentro): quem tira o item da tela é a lista
  /// atualizada, não o gesto de deslizar.
  Future<bool> _confirmarRemocao(Solicitacao s) async {
    final store = AppScope.read(context);
    // Abre a caixinha de confirmação e espera a escolha (true, false ou nulo se tocou fora).
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover solicitação?'),
        content: Text('"${s.nome}" será removido da lista.'),
        actions: [
          TextButton(
              // Navigator.pop fecha o diálogo devolvendo o valor escolhido.
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('remover')),
        ],
      ),
    );
    // Cancelou (ou tocou fora): não faz nada.
    if (ok != true) return false;
    try {
      // Remove no servidor; o store tira o item da lista, então o Dismissible
      // não precisa (nem deve) sair sozinho — devolvemos false.
      await store.removerSolicitacao(s.id);
    } on ApiException catch (e) {
      if (mounted) _erro(e);
    }
    return false;
  }

  /// Abre o formulário "Registrar solicitação" como uma folha que sobe de baixo.
  /// Chamada quando o usuário toca no botão "+" flutuante.
  void _abrirRegistro() {
    showModalBottomSheet<void>(
      context: context,
      // true = a folha pode ser mais alta que o padrão (necessário para o teclado não cobrir os campos).
      isScrollControlled: true,
      backgroundColor: AppCores.of(context).superficie,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => const _FormularioSolicitacao(),
    );
  }

  /// Desenha a tela. O Flutter chama `build` sempre que algo muda (lista de
  /// solicitações atualizada, item ficou ocupado...).
  @override
  Widget build(BuildContext context) {
    final c = AppCores.of(context);
    final store = AppScope.of(context);
    // `[...lista]` copia a lista (para não alterar a original do estado global) e
    // `..sort(...)` (cascata) ordena a cópia: quem tem mais pedidos vem primeiro
    // (b comparado com a = ordem decrescente).
    final lista = [...store.estado.solicitacoes]
      ..sort((a, b) => b.pedidos.compareTo(a.pedidos));

    // [ESCRITO À MÃO] Scaffold + body Column do esqueleto — AppBar substituído pelo Cabecalho (Figma)
    // Scaffold: o esqueleto da tela; aqui tem o botão flutuante e o corpo.
    return Scaffold(
      // FloatingActionButton (FAB): botão redondo "+" que flutua sobre a tela.
      floatingActionButton: FloatingActionButton(
        backgroundColor: c.destaque,
        foregroundColor: Colors.white,
        tooltip: 'Registrar solicitação',
        onPressed: _abrirRegistro,
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Cabecalho(
              titulo: 'Solicitados',
              subtitulo: 'Pedidos de clientes',
              descricao: 'Pedidos de clientes que você ainda não tem em estoque.',
            ),
            // Expanded: a lista usa o resto da altura da tela.
            Expanded(
              // Puxar a lista para baixo recarrega os dados do servidor.
              child: RefreshIndicator(
                onRefresh: () => AppScope.read(context).recarregar(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  // 88 embaixo: deixa espaço para o botão flutuante não cobrir o último item.
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 88),
                  children: [
                    // Resumo ("n produto(s)...") só aparece se houver itens.
                    if (lista.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 2, bottom: 8),
                        child: Text(
                            '${lista.length} produto(s) solicitado(s) por clientes',
                            style:
                                TextStyle(fontSize: 12, color: c.textoSuave)),
                      ),
                    // Lista vazia: mostra o aviso com uma dica; senão, o cartão com os itens.
                    if (lista.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: c.superficie,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: c.borda),
                        ),
                        child: Column(
                          children: [
                            const Vazio(
                                icone: Ico.solicitados,
                                texto: 'Nenhuma solicitação ainda'),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Text(
                                  'Sempre que um cliente pedir algo que você não tem, registre aqui.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 12, color: c.textoSuave)),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: c.superficie,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: c.borda),
                        ),
                        // Corta o conteúdo nos cantos arredondados.
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            // Um item para cada solicitação; o primeiro não leva linha divisória em cima.
                            for (var i = 0; i < lista.length; i++)
                              _item(lista[i], primeiro: i == 0),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    // [FIM ESCRITO À MÃO]
  }

  /// Desenha UM item da lista: nome, observação, data do último pedido, selo com o
  /// total de pedidos e o botão "+1". [s] é a solicitação; [primeiro] indica se é o
  /// primeiro da lista (muda só a linha divisória de cima).
  Widget _item(Solicitacao s, {required bool primeiro}) {
    final c = AppCores.of(context);
    // true se há uma requisição em andamento para este item.
    final ocupado = _ocupados.contains(s.id);
    // Dismissible: permite deslizar o item para o lado para removê-lo.
    return Dismissible(
      // key identifica o item de forma única, para o Flutter não confundir itens ao
      // reordenar/remover.
      key: ValueKey(s.id),
      // Só desliza da direita para a esquerda.
      direction: DismissDirection.endToStart,
      // Antes de sumir, chama a confirmação; o valor devolvido (false) manda não remover da tela.
      confirmDismiss: (_) => _confirmarRemocao(s),
      // Fundo vermelho com lixeira, revelado enquanto o item é deslizado.
      background: Container(
        color: c.perigo,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: c.superficie,
          border: primeiro ? null : Border(top: BorderSide(color: c.borda)),
        ),
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(
          children: [
            // Expanded: os textos ocupam o espaço e empurram selo e botão para a direita.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.nome,
                      style: TextStyle(fontSize: 14, color: c.texto)),
                  // A observação só aparece se foi preenchida.
                  if (s.nota.isNotEmpty)
                    Text(s.nota,
                        style: TextStyle(fontSize: 12, color: c.textoSuave)),
                  Text('Último pedido em ${formatarDataIso(s.data)}',
                      style: TextStyle(fontSize: 12, color: c.textoSuave)),
                ],
              ),
            ),
            Selo('${s.pedidos} pedido(s)'),
            IconButton(
              tooltip: '+1 pedido',
              visualDensity: VisualDensity.compact,
              // Travado (null) enquanto ocupado, para evitar toque duplo.
              onPressed: ocupado ? null : () => _somar(s),
              // Enquanto ocupado mostra uma rodinha pequena; senão o texto "+1".
              icon: ocupado
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('+1',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: c.destaque)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet "Registrar solicitação de cliente".
///
/// "Bottom sheet" = a folha que sobe de baixo da tela. É um StatefulWidget porque
/// guarda o que muda enquanto o formulário está aberto (enviando, mensagem de erro).
/// O `_` no nome = privado a este arquivo. Aberto por `_abrirRegistro`.
class _FormularioSolicitacao extends StatefulWidget {
  const _FormularioSolicitacao();

  /// Cria a "memória" (State) do formulário.
  @override
  State<_FormularioSolicitacao> createState() => _FormularioSolicitacaoState();
}

/// Memória e desenho do formulário de nova solicitação.
class _FormularioSolicitacaoState extends State<_FormularioSolicitacao> {
  /// Controller do campo "O que o cliente pediu?" (lê o texto digitado).
  final _nome = TextEditingController();

  /// Controller do campo de observação (opcional).
  final _nota = TextEditingController();

  /// true enquanto a solicitação está sendo enviada ao servidor (trava os campos e o botão).
  bool _enviando = false;

  /// Mensagem de erro mostrada embaixo do campo do nome; nulo = sem erro.
  String? _erroNome;

  /// Chamado pelo Flutter quando o formulário é fechado: libera os controllers.
  /// (veja GUIA_FLUTTER.md → dispose)
  @override
  void dispose() {
    _nome.dispose();
    _nota.dispose();
    super.dispose();
  }

  /// Valida e envia a nova solicitação. Chamada quando o usuário toca em "registrar".
  /// Passos: (1) confere se o nome não está vazio, (2) trava o formulário,
  /// (3) envia ao servidor, (4) fecha a folha; se falhar, mostra o erro nela mesma.
  Future<void> _enviar() async {
    // `trim()` tira espaços do começo e do fim (para "   " contar como vazio).
    final nome = _nome.text.trim();
    // (1) Nome obrigatório: mostra o erro no campo e para.
    if (nome.isEmpty) {
      setState(() => _erroNome = 'Informe o que o cliente pediu.');
      return;
    }
    // Pegamos estes objetos ANTES do `await`; depois da espera o `context` pode não ser mais seguro.
    final store = AppScope.read(context);
    final navigator = Navigator.of(context);
    // (2) Trava o formulário e limpa o erro anterior.
    setState(() {
      _enviando = true;
      _erroNome = null;
    });
    try {
      // (3) Envia (a observação também é limpa com trim()).
      await store.registrarSolicitacao(nome, _nota.text.trim());
      // (4) Deu certo: fecha a folha.
      navigator.pop();
    } on ApiException catch (e) {
      // Erro dentro do próprio sheet: um SnackBar ficaria escondido atrás dele.
      if (mounted) {
        setState(() {
          _enviando = false;
          _erroNome = e.message;
        });
      }
    }
  }

  /// Monta a aparência (borda, cores, rótulo) dos campos do formulário, para os
  /// dois campos ficarem iguais. Recebe as cores [c], o título flutuante [rotulo],
  /// um texto de exemplo opcional [hint] e uma mensagem de erro opcional [erro].
  InputDecoration _deco(AppCores c, String rotulo, {String? hint, String? erro}) =>
      InputDecoration(
        labelText: rotulo,
        hintText: hint,
        errorText: erro,
        labelStyle: TextStyle(color: c.textoSuave),
        hintStyle: TextStyle(color: c.textoFraco),
        filled: true,
        fillColor: c.fundo,
        // Borda cinza normal e borda laranja quando o campo está em foco.
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: c.borda)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: c.destaque)),
      );

  /// Desenha o formulário: título, campo do nome, campo de observação e o botão.
  @override
  Widget build(BuildContext context) {
    final c = AppCores.of(context);
    return Padding(
      // Sobe junto com o teclado.
      // `viewInsets.bottom` = altura ocupada pelo teclado; usá-la de folga embaixo
      // empurra o formulário para cima do teclado.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      // SingleChildScrollView: se a tela for pequena, o conteúdo rola em vez de estourar.
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          // min = a folha tem só a altura do conteúdo.
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Registrar solicitação de cliente',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: c.texto)),
            const SizedBox(height: 16),
            TextField(
              controller: _nome,
              // Trava o campo enquanto envia.
              enabled: !_enviando,
              // Já abre com o cursor aqui e o teclado aberto.
              autofocus: true,
              // O botão do teclado vira "próximo" (vai para o campo seguinte).
              textInputAction: TextInputAction.next,
              style: TextStyle(color: c.texto),
              decoration: _deco(c, 'O que o cliente pediu?',
                  hint: 'Pomada para queimadura', erro: _erroNome),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nota,
              enabled: !_enviando,
              // Campo de várias linhas: começa com 2 e cresce até 4.
              minLines: 2,
              maxLines: 4,
              keyboardType: TextInputType.multiline,
              style: TextStyle(color: c.texto),
              decoration: _deco(c, 'Observação (opcional)'),
            ),
            const SizedBox(height: 16),
            // `carregando` mostra a rodinha e bloqueia o toque durante o envio.
            BotaoLaranja(
              texto: 'registrar',
              carregando: _enviando,
              onPressed: _enviar,
            ),
          ],
        ),
      ),
    );
  }
}
