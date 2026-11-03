// O QUE É ESTE ARQUIVO
// Define o `Cabecalho`: a faixa do topo de cada tela (ex.: "Estoque / 120 itens"),
// com uma descrição opcional embaixo e o botão que alterna tema claro/escuro.
// É usado pelas telas principais (estoque, contagem, solicitados...).
// Usa as cores do tema (theme/app_theme.dart), o estado global (state/app_scope.dart,
// para trocar o tema) e os ícones (icones.dart).
import 'package:flutter/material.dart';

import '../state/app_scope.dart';
import '../theme/app_theme.dart';
import 'icones.dart';

/// "Título / subtítulo" + descrição + botão de tema. Usar dentro de SafeArea.
///
/// É um StatelessWidget: um widget "sem memória", que só desenha o que recebeu
/// pelo construtor e não muda sozinho. (veja GUIA_FLUTTER.md → StatelessWidget)
class Cabecalho extends StatelessWidget {
  /// Construtor `const`: permite o Flutter reaproveitar o widget sem recriá-lo.
  /// `required` = a tela é obrigada a informar; sem `required` é opcional.
  const Cabecalho({
    super.key,
    required this.titulo,
    required this.subtitulo,
    this.descricao,
    this.acoes,
  });

  /// Texto principal, em letra maior (ex.: "Estoque").
  final String titulo;

  /// Texto menor, em cinza, mostrado depois de " / " ao lado do título.
  final String subtitulo;

  /// Linha de explicação opcional abaixo do título. `String?` = pode ser nulo.
  final String? descricao;

  /// Botões extras exibidos antes do botão de tema.
  final List<Widget>? acoes;

  /// Monta o desenho do cabeçalho. O Flutter chama `build` sempre que a tela
  /// precisa ser (re)desenhada. Recebe o `context` (o "endereço" deste widget na
  /// árvore, usado para perguntar o tema e o estado global) e devolve a árvore
  /// de widgets. (veja GUIA_FLUTTER.md → BuildContext)
  @override
  Widget build(BuildContext context) {
    // Cores do tema atual (claro ou escuro).
    final c = AppCores.of(context);
    // true quando o tema atual é o escuro; define o ícone e a dica do botão.
    final escuro = Theme.of(context).brightness == Brightness.dark;
    // Padding: afasta o conteúdo das bordas. fromLTRB = esquerda, topo, direita, base.
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 12),
      // Column: empilha os filhos na vertical. `start` alinha tudo à esquerda.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row: coloca os filhos lado a lado (título à esquerda, botões à direita).
          Row(
            children: [
              // Expanded: o título ocupa todo o espaço que sobrar na linha,
              // empurrando os botões para a direita.
              Expanded(
                // Text.rich permite um único texto com pedaços de estilos diferentes.
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: titulo,
                      style: TextStyle(fontSize: 18, color: c.texto),
                    ),
                    TextSpan(
                      text: ' / $subtitulo',
                      style: TextStyle(fontSize: 15, color: c.textoSuave),
                    ),
                  ]),
                  // Uma linha só; se não couber, termina com "..." em vez de quebrar.
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // `...?acoes`: "espalha" os itens da lista aqui dentro; o `?` faz
              // não inserir nada se `acoes` for nulo.
              ...?acoes,
              // Botão de alternar tema (claro <-> escuro).
              IconButton(
                visualDensity: VisualDensity.compact,
                // Texto que aparece ao segurar o dedo no botão (acessibilidade).
                tooltip: escuro ? 'Tema claro' : 'Tema escuro',
                // No tema escuro mostra o sol (para ir ao claro); no claro, a lua.
                icon: ico(escuro ? Ico.sol : Ico.lua,
                    color: c.textoSuave, size: 24),
                // `read` só lê o estado global, sem redesenhar este widget;
                // é o certo para ações de toque. (veja GUIA_FLUTTER.md → AppScope)
                onPressed: () => AppScope.read(context).alternarTema(),
              ),
            ],
          ),
          // `if` dentro da lista de filhos: só inclui a descrição se ela existir.
          // `...[ ]` espalha os dois widgets (espaço + texto) na lista.
          if (descricao != null) ...[
            const SizedBox(height: 4),
            // `descricao!` = "tenho certeza de que não é nulo" (já checamos acima).
            Text(descricao!,
                style: TextStyle(fontSize: 12, color: c.textoSuave)),
          ],
        ],
      ),
    );
  }
}
