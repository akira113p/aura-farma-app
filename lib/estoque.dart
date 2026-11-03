// O QUE É ESTE ARQUIVO
// A tela "Estoque": lista os medicamentos da farmácia, com busca por nome/código,
// filtro por categoria, "puxar para atualizar" e um painel de detalhes ao tocar num item.
// É uma das abas principais do app (aberta pela barra de abas).
// Usa: o estado global (state/app_scope.dart) para ler a lista de produtos, o modelo
// `Medicamentos` (models.dart), as cores do tema e os widgets prontos de widgets/
// (Cabecalho, LinhaMedicamento, Vazio, BotaoLaranja...).
import 'package:flutter/material.dart';

import 'core/api_client.dart';
import 'models.dart';
import 'state/app_scope.dart';
import 'theme/app_theme.dart';
import 'widgets/cabecalho.dart';
import 'widgets/cartao.dart';
import 'widgets/icones.dart';
import 'widgets/linha_medicamento.dart';

// [ESCRITO À MÃO] TelaEstoque/_TelaEstoque mantidos (StatefulWidget); o import de main.dart saiu
// porque Medicamentos agora vive em models.dart
/// A tela de estoque. É um StatefulWidget: um widget que precisa LEMBRAR de coisas
/// que mudam (aqui, o texto da busca e a categoria escolhida). Por isso são sempre
/// duas classes: esta (só "declara" a tela) e a `_TelaEstoque` (que guarda a memória
/// e desenha). (veja GUIA_FLUTTER.md → StatefulWidget)
class TelaEstoque extends StatefulWidget {
  const TelaEstoque({super.key});

  /// O Flutter chama isto uma vez para criar o objeto `State` (a "memória") desta tela.
  @override
  State<TelaEstoque> createState() => _TelaEstoque();
}

/// A "memória" e o desenho da tela de estoque. O `_` no começo do nome significa
/// privado: só este arquivo enxerga a classe.
class _TelaEstoque extends State<TelaEstoque> {
  // [FIM ESCRITO À MÃO]

  // [ESCRITO À MÃO] a lista hardcoded de 3 medicamentos (listaMed) saiu: os dados agora vêm de
  // AppScope.of(context).estado.produtos. ListaFiltrada virou listaFiltrada (lint) e deixou de ser
  // estado guardado: é recalculada no build a partir do texto da busca + categoria
  /// Texto digitado na caixa de busca (começa vazio).
  String _busca = '';

  /// Categoria escolhida no filtro. `null` significa "todas as categorias".
  String? _categoria;

  /// Aplica a busca e a categoria atuais à lista [todos] e devolve só os que passam.
  /// Chamada dentro do `build`, toda vez que a tela é desenhada.
  List<Medicamentos> filtrarEstoque(List<Medicamentos> todos) {
    // lógica original (nome OU código, case-insensitive) agora delegada para filtrarMedicamentos
    return filtrarMedicamentos(todos, _busca, categoria: _categoria);
  }
  // [FIM ESCRITO À MÃO]

  /// Pede ao estado global para preencher o estoque com medicamentos de exemplo.
  /// Chamada quando o usuário toca em "popular com exemplos" (estoque vazio).
  /// É `async` porque fala com o servidor e demora; o `await` espera a resposta
  /// sem travar a tela. (veja GUIA_FLUTTER.md → async / await)
  Future<void> _popular() async {
    try {
      // `read` só lê o estado global, sem redesenhar a tela (certo para ações).
      await AppScope.read(context).popularExemplo();
    } on ApiException catch (e) {
      // Depois de um await a tela pode já ter sido fechada; se sim, não usamos o
      // `context` (isso daria erro). (veja GUIA_FLUTTER.md → mounted)
      if (!mounted) return;
      // Mostra o erro do servidor num aviso rápido (SnackBar) embaixo da tela.
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// Abre o painel que sobe de baixo da tela com os detalhes do medicamento [m].
  /// Chamada quando o usuário toca numa linha da lista.
  void _detalhes(Medicamentos m) {
    final c = AppCores.of(context);
    // showModalBottomSheet: abre a "folha" que sobe de baixo. O `<void>` diz que
    // ela não devolve nenhum valor ao ser fechada.
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.superficie,
      // Só os cantos de cima são arredondados (16).
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      // `builder` monta o conteúdo da folha; `ctx` é o contexto dela.
      builder: (ctx) {
        // Função local que cria uma linha "rótulo à esquerda, valor à direita".
        // `cor` é opcional (`Color?`); se vier nula, usa a cor de texto normal (`??`).
        Widget item(String rotulo, String valor, {Color? cor}) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                // Expanded: o rótulo ocupa o espaço que sobra e empurra o valor para a direita.
                Expanded(
                    child: Text(rotulo,
                        style: TextStyle(fontSize: 13, color: c.textoSuave))),
                Text(valor,
                    style: TextStyle(fontSize: 14, color: cor ?? c.texto)),
              ]),
            );
        // SafeArea evita que o conteúdo fique embaixo da barra de gestos do celular.
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
            child: Column(
              // min = a folha tem só a altura do conteúdo, não ocupa a tela toda.
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.nome,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: c.texto)),
                const SizedBox(height: 10),
                item('Código', m.codigo),
                item('Categoria', m.categorias),
                // Estoque em vermelho se está em baixa, verde se está ok.
                // `'${m.quantidade}'` converte o número em texto.
                item('Estoque', '${m.quantidade}',
                    cor: m.emBaixa ? c.perigo : c.sucesso),
                item('Mínimo', '${m.minimo}'),
                item('Preço', formatarPreco(m.preco)),
                item('Custo', formatarPreco(m.custo)),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Envolve [child] (um campo de entrada) numa caixa com o visual dos campos do
  /// Figma: altura 37, fundo transparente e borda fina. Usada na busca e no filtro.
  Widget _campo(Widget child) {
    final c = AppCores.of(context);
    // No Figma os campos são transparentes (mesmo cinza do fundo) com borda fina
    return Container(
      height: 37,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.borda),
      ),
      child: child,
    );
  }

  /// Monta a parte de baixo da tela (a lista ou uma mensagem), conforme a situação:
  /// carregando, erro, estoque nunca preenchido, busca sem resultado, ou a tabela.
  /// Recebe o [estado] completo e a lista já [filtrados] pela busca/categoria.
  Widget _corpo(Estado estado, List<Medicamentos> filtrados) {
    final c = AppCores.of(context);
    // `of` (e não `read`): aqui estamos desenhando, então queremos redesenhar
    // quando o estado global mudar. (veja GUIA_FLUTTER.md → AppScope)
    final store = AppScope.of(context);
    // conteúdo centralizado mas rolável, para o puxar-para-atualizar funcionar
    // (o RefreshIndicator só funciona se o filho puder rolar, mesmo com pouco conteúdo).
    // LayoutBuilder informa o espaço disponível (`cons`); com minHeight igual à altura
    // toda, o filho fica centralizado, mas continua "rolável" por causa do
    // AlwaysScrollableScrollPhysics.
    Widget rolavel(Widget filho) => LayoutBuilder(
          builder: (_, cons) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: cons.maxHeight),
              child: Center(child: filho),
            ),
          ),
        );

    // (1) Ainda carregando e sem nada para mostrar: rodinha girando no centro.
    if (store.carregandoEstado && estado.produtos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    // (2) Deu erro ao carregar e não há dados: mostra a mensagem e um botão para repetir.
    // `erroEstado!` = já checamos acima que não é nulo.
    if (store.erroEstado != null && estado.produtos.isEmpty) {
      return rolavel(Column(mainAxisSize: MainAxisSize.min, children: [
        Text(store.erroEstado!,
            textAlign: TextAlign.center, style: TextStyle(color: c.perigo)),
        const SizedBox(height: 12),
        BotaoLaranja(texto: 'tentar de novo', onPressed: store.recarregar),
      ]));
    }
    // (3) Conta nova, estoque nunca preenchido: oferece carregar exemplos.
    if (!estado.populado && estado.produtos.isEmpty) {
      return rolavel(Column(mainAxisSize: MainAxisSize.min, children: [
        const Vazio(icone: Ico.estoque, texto: 'Estoque vazio'),
        BotaoLaranja(texto: 'popular com exemplos', onPressed: _popular),
      ]));
    }
    // (4) Há produtos, mas a busca/filtro não achou nenhum.
    if (filtrados.isEmpty) {
      return rolavel(const Vazio(
          icone: Ico.busca, texto: 'Nenhum produto encontrado'));
    }
    // (5) Caso normal: a tabela com cabeçalho e a lista de linhas.
    return Container(
      // Figma: tabela com o mesmo cinza do fundo, borda fina e cantos quase retos
      // margin = folga POR FORA da caixa (padding seria por dentro).
      margin: const EdgeInsets.fromLTRB(22, 0, 22, 12),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: c.borda),
      ),
      // Corta o conteúdo nos cantos da caixa.
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        const CabecalhoTabelaMedicamentos(),
        Divider(height: 1, color: c.borda),
        // Expanded: a lista ocupa todo o resto da altura (uma lista rolável precisa
        // de altura definida dentro de uma Column).
        Expanded(
          // ListView.separated: lista rolável que só desenha os itens visíveis e
          // põe um separador entre eles.
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: filtrados.length,
            // `_, _` = parâmetros que não vamos usar.
            separatorBuilder: (_, _) => Divider(height: 1, color: c.borda),
            // Chamado para cada linha visível; `i` é a posição na lista.
            // Ao tocar, abre o painel de detalhes daquele medicamento.
            itemBuilder: (_, i) => LinhaMedicamento(
                med: filtrados[i], onTap: () => _detalhes(filtrados[i])),
          ),
        ),
      ]),
    );
  }

  /// Desenha a tela inteira. O Flutter chama `build` sempre que algo muda (uma
  /// letra na busca, uma categoria nova, o estado global atualizado...).
  @override
  Widget build(BuildContext context) {
    final c = AppCores.of(context);
    final store = AppScope.of(context);
    final estado = store.estado;
    // Lista de categorias para o filtro: o `{ for ... }` cria um Set (conjunto sem
    // repetidos) com a categoria de cada produto; `where` descarta as vazias;
    // `toList()` vira lista; `..sort()` (operador cascata) ordena essa mesma lista
    // e ainda devolve a própria lista.
    final categorias = {for (final p in estado.produtos) p.categorias}
        .where((e) => e.isNotEmpty)
        .toList()
      ..sort();
    // se a categoria escolhida sumiu (ex.: recarga), volta para "todas"
    // (o Dropdown dá erro se o valor selecionado não estiver entre as opções).
    final categoriaAtual = categorias.contains(_categoria) ? _categoria : null;
    final filtrados = filtrarEstoque(estado.produtos);

    // Scaffold: o esqueleto da tela (fundo e corpo).
    return Scaffold(
      body: SafeArea(
        child: Column(
          // stretch = os filhos ocupam toda a largura.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Cabecalho(
              titulo: 'Estoque',
              subtitulo: 'Medicamentos e quantidades',
              descricao: '${estado.produtos.length} medicamento(s) no estoque',
            ),
            // Linha com a busca (esquerda) e o filtro de categoria (direita).
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
              child: Row(children: [
                // flex 190 x 154: proporção de largura entre busca e filtro, medida no Figma.
                Expanded(
                  flex: 190,
                  child: _campo(TextField(
                    // A cada letra digitada, guarda o texto e redesenha a tela
                    // (setState avisa o Flutter de que algo mudou).
                    onChanged: (t) => setState(() => _busca = t),
                    style: TextStyle(fontSize: 13, color: c.texto),
                    decoration: InputDecoration(
                      hintText: 'buscar por nome, código',
                      hintStyle: TextStyle(fontSize: 13, color: c.textoSuave),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.all(8),
                        child: ico(Ico.busca, size: 20, color: c.textoSuave),
                      ),
                      // Sem bordas próprias: a borda é a da caixa `_campo`.
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  )),
                ),
                const SizedBox(width: 11),
                Expanded(
                  flex: 154,
                  // Dropdown = lista suspensa. HideUnderline tira a linha padrão de baixo.
                  child: _campo(DropdownButtonHideUnderline(
                    // `<String?>`: o valor pode ser texto ou nulo (nulo = "todas").
                    child: DropdownButton<String?>(
                      value: categoriaAtual,
                      isExpanded: true,
                      dropdownColor: c.superficie,
                      padding: const EdgeInsets.only(left: 8, right: 4),
                      icon: ico(Ico.seta, size: 22, color: c.textoSuave),
                      // herda a fonte do tema (o `style` do Dropdown substitui, não mescla)
                      // `bodyMedium!` = estilo de texto do tema (não é nulo);
                      // `copyWith` copia mudando só tamanho e cor.
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium!
                          .copyWith(fontSize: 13, color: c.texto),
                      items: [
                        // Primeira opção fixa: "todas as categorias" (valor nulo).
                        const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('todas as categorias',
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.ellipsis)),
                        // Uma opção para cada categoria existente.
                        for (final cat in categorias)
                          DropdownMenuItem<String?>(
                              value: cat,
                              child:
                                  Text(cat, overflow: TextOverflow.ellipsis)),
                      ],
                      // Ao escolher uma opção, guarda e redesenha filtrando.
                      onChanged: (v) => setState(() => _categoria = v),
                    ),
                  )),
                ),
              ]),
            ),
            // A lista ocupa o resto da tela. RefreshIndicator = "puxar para baixo
            // para atualizar": ao puxar, chama `store.recarregar` (busca de novo no servidor).
            Expanded(
              child: RefreshIndicator(
                color: c.destaque,
                onRefresh: store.recarregar,
                child: _corpo(estado, filtrados),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
