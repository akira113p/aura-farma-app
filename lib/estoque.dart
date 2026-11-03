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
class TelaEstoque extends StatefulWidget {
  const TelaEstoque({super.key});

  @override
  State<TelaEstoque> createState() => _TelaEstoque();
}

class _TelaEstoque extends State<TelaEstoque> {
  // [FIM ESCRITO À MÃO]

  // [ESCRITO À MÃO] a lista hardcoded de 3 medicamentos (listaMed) saiu: os dados agora vêm de
  // AppScope.of(context).estado.produtos. ListaFiltrada virou listaFiltrada (lint) e deixou de ser
  // estado guardado: é recalculada no build a partir do texto da busca + categoria
  String _busca = '';
  String? _categoria;

  List<Medicamentos> filtrarEstoque(List<Medicamentos> todos) {
    // lógica original (nome OU código, case-insensitive) agora delegada para filtrarMedicamentos
    return filtrarMedicamentos(todos, _busca, categoria: _categoria);
  }
  // [FIM ESCRITO À MÃO]

  Future<void> _popular() async {
    try {
      await AppScope.read(context).popularExemplo();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _detalhes(Medicamentos m) {
    final c = AppCores.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.superficie,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        Widget item(String rotulo, String valor, {Color? cor}) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                Expanded(
                    child: Text(rotulo,
                        style: TextStyle(fontSize: 13, color: c.textoSuave))),
                Text(valor,
                    style: TextStyle(fontSize: 14, color: cor ?? c.texto)),
              ]),
            );
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
            child: Column(
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

  Widget _corpo(Estado estado, List<Medicamentos> filtrados) {
    final c = AppCores.of(context);
    final store = AppScope.of(context);
    // conteúdo centralizado mas rolável, para o puxar-para-atualizar funcionar
    Widget rolavel(Widget filho) => LayoutBuilder(
          builder: (_, cons) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: cons.maxHeight),
              child: Center(child: filho),
            ),
          ),
        );

    if (store.carregandoEstado && estado.produtos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (store.erroEstado != null && estado.produtos.isEmpty) {
      return rolavel(Column(mainAxisSize: MainAxisSize.min, children: [
        Text(store.erroEstado!,
            textAlign: TextAlign.center, style: TextStyle(color: c.perigo)),
        const SizedBox(height: 12),
        BotaoLaranja(texto: 'tentar de novo', onPressed: store.recarregar),
      ]));
    }
    if (!estado.populado && estado.produtos.isEmpty) {
      return rolavel(Column(mainAxisSize: MainAxisSize.min, children: [
        const Vazio(icone: Ico.estoque, texto: 'Estoque vazio'),
        BotaoLaranja(texto: 'popular com exemplos', onPressed: _popular),
      ]));
    }
    if (filtrados.isEmpty) {
      return rolavel(const Vazio(
          icone: Ico.busca, texto: 'Nenhum produto encontrado'));
    }
    return Container(
      // Figma: tabela com o mesmo cinza do fundo, borda fina e cantos quase retos
      margin: const EdgeInsets.fromLTRB(22, 0, 22, 12),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: c.borda),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        const CabecalhoTabelaMedicamentos(),
        Divider(height: 1, color: c.borda),
        Expanded(
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: filtrados.length,
            separatorBuilder: (_, _) => Divider(height: 1, color: c.borda),
            itemBuilder: (_, i) => LinhaMedicamento(
                med: filtrados[i], onTap: () => _detalhes(filtrados[i])),
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppCores.of(context);
    final store = AppScope.of(context);
    final estado = store.estado;
    final categorias = {for (final p in estado.produtos) p.categorias}
        .where((e) => e.isNotEmpty)
        .toList()
      ..sort();
    // se a categoria escolhida sumiu (ex.: recarga), volta para "todas"
    final categoriaAtual = categorias.contains(_categoria) ? _categoria : null;
    final filtrados = filtrarEstoque(estado.produtos);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Cabecalho(
              titulo: 'Estoque',
              subtitulo: 'Medicamentos e quantidades',
              descricao: '${estado.produtos.length} medicamento(s) no estoque',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
              child: Row(children: [
                Expanded(
                  flex: 190,
                  child: _campo(TextField(
                    onChanged: (t) => setState(() => _busca = t),
                    style: TextStyle(fontSize: 13, color: c.texto),
                    decoration: InputDecoration(
                      hintText: 'buscar por nome, código',
                      hintStyle: TextStyle(fontSize: 13, color: c.textoSuave),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.all(8),
                        child: ico(Ico.busca, size: 20, color: c.textoSuave),
                      ),
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
                  child: _campo(DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: categoriaAtual,
                      isExpanded: true,
                      dropdownColor: c.superficie,
                      padding: const EdgeInsets.only(left: 8, right: 4),
                      icon: ico(Ico.seta, size: 22, color: c.textoSuave),
                      // herda a fonte do tema (o `style` do Dropdown substitui, não mescla)
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium!
                          .copyWith(fontSize: 13, color: c.texto),
                      items: [
                        const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('todas as categorias',
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.ellipsis)),
                        for (final cat in categorias)
                          DropdownMenuItem<String?>(
                              value: cat,
                              child:
                                  Text(cat, overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (v) => setState(() => _categoria = v),
                    ),
                  )),
                ),
              ]),
            ),
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
