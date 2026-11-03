// O QUE É ESTE ARQUIVO
// A tela "Contagem": serve para conferir o estoque FÍSICO (o que está na prateleira)
// contra o estoque do SISTEMA. Tem dois modos: (1) tela inicial, com botão para
// começar e o histórico de contagens anteriores; (2) "sessão" de contagem, em que o
// usuário digita a quantidade real de cada produto e, no fim, aplica os ajustes.
// É uma aba principal do app. Usa o estado global (state/app_scope.dart), o modelo
// `Medicamentos`/`Contagem` (models.dart) e os widgets prontos de widgets/.
import 'package:flutter/material.dart';
// Traz o `FilteringTextInputFormatter` (usado para aceitar só dígitos nos campos).
import 'package:flutter/services.dart';

import 'core/api_client.dart';
import 'models.dart';
import 'state/app_scope.dart';
import 'theme/app_theme.dart';
import 'widgets/cabecalho.dart';
import 'widgets/cartao.dart';
import 'widgets/icones.dart';

// [ESCRITO À MÃO] esqueleto original: TelaContagem (StatefulWidget) + _TelaContagem com Scaffold.
// Mantidos os nomes das classes; o AppBar(title: "Contagem") foi trocado pelo Cabecalho do Figma
// e o Column vazio do body agora recebe o conteúdo da tela.
/// A tela de contagem. É um StatefulWidget: precisa lembrar de coisas que mudam
/// (se há sessão aberta, o que já foi digitado). A memória fica na classe
/// `_TelaContagem` abaixo. (veja GUIA_FLUTTER.md → StatefulWidget)
class TelaContagem extends StatefulWidget {
  const TelaContagem({super.key});

  /// O Flutter chama isto uma vez para criar a "memória" (State) da tela.
  @override
  State<TelaContagem> createState() => _TelaContagem();
}

/// Memória e desenho da tela de contagem (o `_` = privada a este arquivo).
class _TelaContagem extends State<TelaContagem> {
  // [FIM ESCRITO À MÃO]

  /// Sessão de contagem aberta?
  /// false = mostra a tela inicial; true = mostra a lista para contar.
  bool _emSessao = false;

  /// id do produto -> texto digitado (só dígitos).
  /// Só guarda produtos que o usuário já preencheu; os não preenchidos não aparecem aqui.
  final Map<String, String> _contados = {};

  /// Um controller por produto (criado sob demanda; descartado ao sair da sessão).
  /// Um TextEditingController é o "controle remoto" de um campo de texto: lê e
  /// altera o que está escrito nele. (veja GUIA_FLUTTER.md → Controllers)
  final Map<String, TextEditingController> _controllers = {};

  /// Controller da caixa de busca da sessão.
  final TextEditingController _busca = TextEditingController();

  /// true enquanto os ajustes estão sendo enviados ao servidor (trava os botões/campos).
  bool _aplicando = false;

  /// Chamado pelo Flutter uma vez, quando a tela morre. Libera os controllers
  /// (senão ficam ocupando memória). (veja GUIA_FLUTTER.md → dispose)
  @override
  void dispose() {
    _busca.dispose();
    _descartarControllers();
    super.dispose();
  }

  /// Descarta todos os controllers dos produtos e esvazia o mapa.
  /// Só é chamada no `dispose`, quando a tela inteira já está saindo.
  void _descartarControllers() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
  }

  /// Devolve o controller do campo do produto [id]; cria um se ainda não existir
  /// (`putIfAbsent`). O texto inicial é o que já estava digitado (`??` = ou '' se nulo).
  /// Chamada ao desenhar cada linha de produto.
  TextEditingController _controllerDe(String id) =>
      _controllers.putIfAbsent(id, () => TextEditingController(text: _contados[id] ?? ''));

  /// Começa uma sessão de contagem nova: zera o que havia e liga o modo sessão.
  /// Chamada quando o usuário toca em "começar contagem".
  void _iniciar() {
    // setState avisa o Flutter para redesenhar a tela com os novos valores.
    setState(() {
      _emSessao = true;
      _contados.clear();
      _busca.clear();
    });
  }

  /// Encerra a sessão (por cancelar ou depois de aplicar com sucesso) e volta à
  /// tela inicial. Chamada pelo botão "cancelar" e ao fim de `_aplicar`.
  void _encerrarSessao() {
    // Os TextFields da sessão ainda estão montados neste frame: só descarta os
    // controllers depois que a árvore for reconstruída sem eles.
    // (Descartar um controller que ainda está sendo usado por um campo na tela
    // causaria erro; por isso copiamos a lista, limpamos o mapa e esperamos.)
    final antigos = _controllers.values.toList();
    _controllers.clear();
    setState(() {
      _emSessao = false;
      _contados.clear();
      _busca.clear();
    });
    // addPostFrameCallback: roda a função DEPOIS que o Flutter terminar de
    // desenhar o próximo quadro (frame), quando os campos já saíram da tela.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in antigos) {
        c.dispose();
      }
    });
  }

  /// Guarda o que o usuário digitou para o produto [id]. Se [valor] ficou vazio,
  /// remove o produto de `_contados` (conta como "não contado").
  /// Chamada a cada tecla digitada num campo de quantidade.
  void _alterou(String id, String valor) {
    setState(() {
      if (valor.isEmpty) {
        _contados.remove(id);
      } else {
        _contados[id] = valor;
      }
    });
  }

  /// Envia os ajustes ao servidor depois de o usuário confirmar num diálogo.
  /// Chamada quando toca em "aplicar (n)". Passos: (1) monta o mapa de ajustes,
  /// (2) pede confirmação, (3) envia e mostra o resultado, (4) fecha a sessão.
  /// É `async` porque pergunta ao usuário e fala com o servidor.
  Future<void> _aplicar() async {
    // Guardamos estas referências ANTES dos `await`: depois de esperar, a tela pode
    // ter mudado e usar `context` seria arriscado.
    final store = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    // (1) Converte os textos digitados em números (id -> quantidade contada).
    // `int.tryParse` devolve nulo se não for número; esses são ignorados.
    final ajustes = <String, int>{};
    _contados.forEach((id, v) {
      final n = int.tryParse(v);
      if (n != null) ajustes[id] = n;
    });
    // Nada para aplicar: sai sem fazer nada.
    if (ajustes.isEmpty) return;

    // (2) Abre uma caixinha de confirmação e ESPERA a escolha do usuário.
    // `showDialog<bool>` devolve true (aplicar), false (cancelar) ou nulo (tocou fora).
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aplicar contagem?'),
        content: Text(
            '${ajustes.length} produto(s) terão o estoque do sistema ajustado para o valor contado.'),
        actions: [
          TextButton(
              // Navigator.pop fecha o diálogo e devolve o valor escolhido.
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('aplicar')),
        ],
      ),
    );
    // Só segue se confirmou (== true; nulo/false cancela) e a tela ainda existe.
    if (ok != true || !mounted) return;

    // (3) Liga o modo "aplicando" (botões travados) e envia ao servidor.
    setState(() => _aplicando = true);
    try {
      await store.aplicarContagem(ajustes);
      messenger.showSnackBar(SnackBar(
          content: Text('Contagem aplicada · ${ajustes.length} ajuste(s) salvos')));
      // (4) Deu certo: fecha a sessão (se a tela ainda estiver viva).
      if (mounted) _encerrarSessao();
    } on ApiException catch (e) {
      // Erro vindo da API: mostra a mensagem e mantém a sessão aberta para tentar de novo.
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      // `finally` roda sempre (com ou sem erro): destrava a tela.
      if (mounted) setState(() => _aplicando = false);
    }
  }

  /// Desenha a tela. Escolhe entre: carregando, sem produtos, sessão de contagem
  /// ou tela inicial. Chamada pelo Flutter sempre que algo muda.
  @override
  Widget build(BuildContext context) {
    // `of` = lê o estado global E faz esta tela se redesenhar quando ele mudar.
    final store = AppScope.of(context);
    final estado = store.estado;

    // [ESCRITO À MÃO] Scaffold + body Column do esqueleto — AppBar substituído pelo Cabecalho (Figma)
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Cabecalho(
              titulo: 'Contagem',
              subtitulo: 'Conferir estoque físico',
              descricao: 'Conferência periódica do estoque físico vs sistema.',
            ),
            // Expanded: o conteúdo usa o resto da altura. A cadeia de `? :` abaixo lê-se:
            // se está carregando -> rodinha; senão, se não há produtos -> aviso vazio;
            // senão, se em sessão -> lista para contar; senão -> tela inicial.
            Expanded(
              child: store.carregandoEstado && !estado.populado
                  ? Center(
                      child: CircularProgressIndicator(
                          color: AppCores.of(context).destaque))
                  : !estado.populado
                  ? const Center(
                      child: Vazio(
                          icone: Ico.contagem,
                          texto: 'Sem produtos para contar'))
                  : (_emSessao
                      ? _sessao(estado.produtos)
                      : _inicio(estado.contagens)),
            ),
          ],
        ),
      ),
    );
    // [FIM ESCRITO À MÃO]
  }

  // ------------------------------------------------------------ sem sessão

  /// Tela inicial (sem sessão aberta): cartão para começar uma contagem e a lista
  /// das últimas contagens já feitas. Recebe [contagens] (o histórico completo).
  Widget _inicio(List<Contagem> contagens) {
    final c = AppCores.of(context);
    // Só as 10 mais recentes aparecem na tela.
    final recentes = contagens.take(10).toList();
    // RefreshIndicator: puxar a lista para baixo recarrega os dados do servidor.
    return RefreshIndicator(
      onRefresh: () => AppScope.read(context).recarregar(),
      // ListView: coluna que rola. AlwaysScrollable deixa "puxar" mesmo com pouco conteúdo.
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            // Figma: o cartão "Iniciar nova contagem" é transparente (cinza do fundo) com borda
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.borda),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Iniciar nova contagem',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: c.texto)),
                const SizedBox(height: 6),
                Text(
                    'Percorra a farmácia e registre o estoque físico de cada produto. Ao final, aplique os ajustes para alinhar o sistema com a realidade.',
                    style: TextStyle(fontSize: 13, color: c.textoSuave)),
                const SizedBox(height: 12),
                // Align encosta o botão à esquerda (sem isso ele esticaria na largura toda).
                Align(
                  alignment: Alignment.centerLeft,
                  child: BotaoLaranja(
                    texto: 'começar contagem',
                    icone: Ico.contagem,
                    onPressed: _iniciar,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          CartaoComFaixa(
            titulo: 'Contagens anteriores',
            contador: '${contagens.length} realizada(s)',
            child: recentes.isEmpty
                ? const Vazio(
                    icone: Ico.contagem, texto: 'Nenhuma contagem ainda')
                : Column(
                    children: [
                      // `for` dentro da lista de filhos: uma linha por contagem.
                      // `primeira` é true só para i == 0 (a primeira não tem linha divisória em cima).
                      for (var i = 0; i < recentes.length; i++)
                        _linhaContagem(recentes[i], primeira: i == 0),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// Uma linha do histórico: data/hora, quantos ajustes e um selo com a diferença
  /// total. [ct] é a contagem; [primeira] indica se é a primeira da lista.
  Widget _linhaContagem(Contagem ct, {required bool primeira}) {
    final c = AppCores.of(context);
    final dif = ct.diferencaTotal;
    // Cor do selo: verde se não houve diferença, laranja se sobrou (positivo),
    // amarelo/aviso se faltou (negativo).
    final tom = dif == 0
        ? TomSelo.sucesso
        : (dif > 0 ? TomSelo.destaque : TomSelo.aviso);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        // Linha fina em cima separando das anteriores; a primeira não tem.
        border: primeira ? null : Border(top: BorderSide(color: c.borda)),
      ),
      child: Row(
        children: [
          // Expanded: o bloco de textos ocupa o espaço e empurra o selo para a direita.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formatarDataHora(ct.quando),
                    style: TextStyle(fontSize: 14, color: c.texto)),
                Text('${ct.ajustes.length} ajuste(s) aplicado(s)',
                    style: TextStyle(fontSize: 12, color: c.textoSuave)),
              ],
            ),
          ),
          // Mostra "+" na frente quando a diferença é positiva (negativa já traz "-").
          Selo('Diferença ${dif > 0 ? '+' : ''}$dif', tom: tom),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- sessão

  /// Tela da sessão de contagem: caixa de busca, resumo ("x de y contados"),
  /// botões cancelar/aplicar e a lista de produtos com um campo para cada um.
  /// Recebe [produtos] (todos os medicamentos do estoque).
  Widget _sessao(List<Medicamentos> produtos) {
    final c = AppCores.of(context);
    // Filtra pela busca (lê o texto direto do controller).
    final lista = filtrarMedicamentos(produtos, _busca.text);
    final contados = _contados.length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // SizedBox com altura fixa para o campo de busca.
              SizedBox(
                height: 40,
                child: TextField(
                  controller: _busca,
                  // Redesenha a cada letra para a lista ser refiltrada.
                  // `(_)` = ignora o texto recebido (já lemos pelo controller).
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(fontSize: 14, color: c.texto),
                  decoration: InputDecoration(
                    hintText: 'buscar por nome, código',
                    hintStyle: TextStyle(fontSize: 13, color: c.textoFraco),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(10),
                      child: ico(Ico.busca, size: 20, color: c.textoSuave),
                    ),
                    filled: true,
                    fillColor: c.superficie,
                    contentPadding: EdgeInsets.zero,
                    // Borda normal cinza e borda laranja quando o campo está em foco.
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: c.borda)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: c.destaque)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text('$contados de ${produtos.length} contados',
                        style: TextStyle(fontSize: 12, color: c.textoSuave)),
                  ),
                  TextButton(
                    // null desabilita o botão enquanto está aplicando.
                    onPressed: _aplicando ? null : _encerrarSessao,
                    child: Text('cancelar',
                        style: TextStyle(color: c.textoSuave)),
                  ),
                  const SizedBox(width: 6),
                  BotaoLaranja(
                    texto: 'aplicar ($contados)',
                    carregando: _aplicando,
                    // Sem nenhum produto contado, o botão fica desabilitado.
                    onPressed: contados == 0 ? null : _aplicar,
                  ),
                ],
              ),
            ],
          ),
        ),
        // A lista de produtos ocupa o resto da altura.
        Expanded(
          child: lista.isEmpty
              ? Center(
                  child: Text('Nenhum produto encontrado',
                      style: TextStyle(fontSize: 13, color: c.textoSuave)))
              // ListView.builder: só desenha as linhas visíveis (bom para listas grandes).
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
                  itemCount: lista.length,
                  itemBuilder: (_, i) => _linhaProduto(lista[i], i == 0),
                ),
        ),
      ],
    );
  }

  /// Uma linha da sessão: dados do produto [p] à esquerda, campo numérico para
  /// digitar a quantidade contada e, à direita, um selo com a diferença para o
  /// sistema. [primeira] diz se é a 1ª da lista (para desenhar a borda de cima).
  Widget _linhaProduto(Medicamentos p, bool primeira) {
    final c = AppCores.of(context);
    // Quantidade digitada como número; nulo se vazio ou ainda não contado.
    final n = int.tryParse(_contados[p.id] ?? '');
    // `final Widget selo;` é declarado agora e recebe o valor logo abaixo (if/else).
    final Widget selo;
    if (n == null) {
      // Ainda não contado: mostra um traço.
      selo = Text('—', style: TextStyle(fontSize: 12, color: c.textoFraco));
    } else {
      // Diferença = contado - sistema (positivo: sobra; negativo: falta).
      final d = n - p.quantidade;
      selo = d == 0
          ? const Selo('igual', tom: TomSelo.sucesso)
          : Selo(d > 0 ? '+$d' : '$d',
              tom: d > 0 ? TomSelo.destaque : TomSelo.aviso);
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: c.superficie,
        // Bordas dos 3 lados sempre; a de cima só na primeira linha (nas outras,
        // a borda de baixo da linha anterior já faz esse papel).
        border: Border(
          left: BorderSide(color: c.borda),
          right: BorderSide(color: c.borda),
          bottom: BorderSide(color: c.borda),
          top: primeira ? BorderSide(color: c.borda) : BorderSide.none,
        ),
      ),
      child: Row(
        children: [
          // Coluna da esquerda: nome, código e quantidade atual do sistema.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.nome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: c.texto)),
                Text(p.codigo,
                    style: TextStyle(fontSize: 10, color: c.textoSuave)),
                Text('sistema: ${p.quantidade}',
                    style: TextStyle(fontSize: 11, color: c.textoSuave)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Campo de quantidade: caixa fixa de 70x38.
          SizedBox(
            width: 70,
            height: 38,
            child: TextField(
              controller: _controllerDe(p.id),
              // Desabilitado enquanto os ajustes estão sendo enviados.
              enabled: !_aplicando,
              // Teclado numérico + filtro que só deixa passar dígitos (0-9).
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: c.texto),
              onChanged: (v) => _alterou(p.id, v),
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: TextStyle(color: c.textoFraco),
                contentPadding: EdgeInsets.zero,
                filled: true,
                fillColor: c.fundo,
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: c.borda)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: c.destaque)),
              ),
            ),
          ),
          // Reserva 62 de largura para o selo, assim o campo não "pula" quando o
          // selo muda de tamanho (ex.: de "—" para "+120").
          SizedBox(width: 62, child: Center(child: selo)),
        ],
      ),
    );
  }
}
