// O QUE É ESTE ARQUIVO: transforma o texto que a IA devolve (escrito em "markdown
// simples") em widgets bonitos. A IA manda coisas como `**negrito**`, listas com `- item`
// e tabelas com `| a | b |`; o Flutter não entende isso sozinho, então este arquivo lê
// o texto e desenha: negrito de verdade, bolinhas nas listas e uma tabela com bordas.
// Quem usa: `assistente.dart` (as bolhas de resposta da IA). Não usa nenhum pacote de markdown.
// Fluxo: texto -> parseBlocos (separa tabelas do resto) -> normalizarListas (vira "•")
// -> parseNegrito (separa **negrito**) -> TextoFormatado desenha tudo.
import 'package:flutter/material.dart';

/// Um pedacinho de texto com uma característica: está em negrito ou não.
/// Ex.: "Estoque: **12** caixas" vira 3 trechos: "Estoque: " (normal), "12" (negrito), " caixas" (normal).
/// Pedaço de texto; [negrito] vem de `**x**`.
class Trecho {
  // Campos: texto = o pedaço de texto; negrito = true se ele deve aparecer em negrito.
  final String texto;
  final bool negrito;
  const Trecho(this.texto, this.negrito);

  // Igualdade por conteúdo: dois Trechos são "iguais" se tiverem o mesmo texto e o mesmo
  // negrito (sem isso, Dart compararia se são o mesmo objeto na memória). Útil nos testes.
  // `other is Trecho` confere o tipo do outro objeto antes de comparar os campos.
  @override
  bool operator ==(Object other) =>
      other is Trecho && other.texto == texto && other.negrito == negrito;

  // O hashCode precisa acompanhar o ==: objetos iguais devem ter o mesmo hashCode
  // (é como o Dart organiza objetos em Sets/Maps). `Object.hash` combina os dois campos.
  @override
  int get hashCode => Object.hash(texto, negrito);
}

/// Recebe a string [s] e devolve uma lista de [Trecho] na mesma ordem em que aparecem.
/// Chamada por `_span` (mais abaixo) para cada pedaço de texto a ser desenhado.
/// Separa `**negrito**` do texto comum (sem pacote de markdown).
/// Marcador sem fechamento é mantido como texto literal.
List<Trecho> parseNegrito(String s) {
  // (1) Expressão regular (RegExp): um "padrão de busca". `\*\*(.+?)\*\*` significa
  // "dois asteriscos, qualquer coisa (o mínimo possível, por causa do `?`), dois asteriscos".
  // `dotAll: true` deixa o `.` casar também com quebra de linha. Os parênteses "capturam"
  // o miolo (grupo 1) que é o texto em negrito sem os asteriscos.
  final out = <Trecho>[];
  final re = RegExp(r'\*\*(.+?)\*\*', dotAll: true);
  // `i` é o ponto até onde já consumimos o texto.
  var i = 0;
  // (2) Para cada ocorrência de **...**: primeiro guarda o texto normal que veio antes
  // dela (se houver), depois o trecho em negrito (`m.group(1)!`: o `!` afirma que não é nulo,
  // o que é verdade pois o grupo sempre participa do padrão), e avança o `i`.
  for (final m in re.allMatches(s)) {
    if (m.start > i) out.add(Trecho(s.substring(i, m.start), false));
    out.add(Trecho(m.group(1)!, true));
    i = m.end;
  }
  // (3) Sobrou texto normal depois do último negrito? Guarda também.
  // Um `**` sem fechamento nunca casa com o padrão, então fica como texto literal.
  if (i < s.length) out.add(Trecho(s.substring(i), false));
  return out;
}

/// Troca o marcador de lista "- item" ou "* item" por "• item" (bolinha de verdade).
/// Mantém as quebras de linha: separa por `\n`, ajusta cada linha e junta de volta.
/// `^(\s*)[-*]\s+` = começo da linha, recuo opcional (preservado em `${m.group(1)}`),
/// um `-` ou `*` e espaços. Só a PRIMEIRA ocorrência da linha é trocada (`replaceFirstMapped`).
/// Itens de lista "- x" / "* x" viram "• x"; as quebras de linha são mantidas.
String normalizarListas(String s) => s
    .split('\n')
    .map((l) => l.replaceFirstMapped(
        RegExp(r'^(\s*)[-*]\s+'), (m) => '${m.group(1)}• '))
    .join('\n');

/// Um "bloco" do texto da IA: ou um parágrafo normal (campo `texto`) ou uma tabela
/// (campo `tabela`). Se `tabela` for nulo, é parágrafo. Dois construtores nomeados
/// (`Bloco.texto` e `Bloco.tabela`) deixam claro qual dos dois está sendo criado.
/// Bloco do texto: parágrafo comum ([tabela] nulo) ou tabela markdown.
class Bloco {
  final String texto;
  // tabela = lista de linhas; cada linha é uma lista de células (textos). A linha 0 é o cabeçalho.
  // O `?` no tipo quer dizer que pode ser nulo (nulo = este bloco não é tabela).
  final List<List<String>>? tabela; // linha 0 = cabeçalho
  const Bloco.texto(this.texto) : tabela = null;
  const Bloco.tabela(List<List<String>> this.tabela) : texto = '';
}

/// Diz se a linha parece linha de tabela markdown: começa e termina com `|`
/// (depois de tirar espaços das pontas) e tem mais de 1 caractere. Função privada (`_`).
bool _linhaDeTabela(String l) {
  final t = l.trim();
  return t.startsWith('|') && t.endsWith('|') && t.length > 1;
}

/// Diz se a linha é a de separação do cabeçalho, como `|---|:---:|`: só pode ter
/// barras, traços, dois-pontos e espaços (`[\s:|-]+`) e precisa ter pelo menos um traço.
/// É essa linha que confirma que o bloco é mesmo uma tabela.
/// A linha de separação `|---|:---:|`.
bool _separador(String l) =>
    RegExp(r'^\|[\s:|-]+\|$').hasMatch(l.trim()) && l.contains('-');

/// Quebra uma linha de tabela em células: tira as barras das pontas (`substring(1, tamanho-1)`),
/// divide em cada `|` e apaga os espaços de cada pedaço. Devolve a lista de textos das células.
List<String> _celulas(String l) {
  final t = l.trim();
  return t
      .substring(1, t.length - 1)
      .split('|')
      .map((c) => c.trim())
      .toList();
}

/// Recebe o texto inteiro [s] e devolve a lista de blocos na ordem original.
/// Chamada por `TextoFormatado.build` antes de desenhar.
/// Estratégia: lê linha por linha; linhas comuns vão acumulando em `texto`; ao achar
/// uma tabela, "fecha" o parágrafo acumulado, lê a tabela e continua.
/// Separa tabelas markdown (`| a | b |` + `|---|---|`) do resto do texto.
List<Bloco> parseBlocos(String s) {
  final out = <Bloco>[];
  final texto = <String>[];
  final linhas = s.split('\n');
  // Função local (declarada dentro de outra função): transforma as linhas acumuladas em
  // um bloco de texto (se não estiver vazio) e zera o acumulador. Chamada antes de cada tabela e no fim.
  void fecharTexto() {
    final t = texto.join('\n').trim();
    if (t.isNotEmpty) out.add(Bloco.texto(t));
    texto.clear();
  }

  // `i` é o índice da linha atual. Usamos `while` (e não `for`) porque, ao ler uma tabela,
  // pulamos várias linhas de uma vez.
  var i = 0;
  while (i < linhas.length) {
    // Linha atual parece tabela E a próxima é o separador? Então começa uma tabela.
    // tabela = cabeçalho + separador + 0..n linhas
    if (_linhaDeTabela(linhas[i]) &&
        i + 1 < linhas.length &&
        _separador(linhas[i + 1])) {
      fecharTexto();
      // A primeira linha da tabela vira o cabeçalho; `i += 2` pula cabeçalho + separador.
      final cab = _celulas(linhas[i]);
      final rows = <List<String>>[cab];
      i += 2;
      // Lê as linhas seguintes enquanto ainda parecerem linhas de tabela.
      while (i < linhas.length && _linhaDeTabela(linhas[i])) {
        final c = _celulas(linhas[i]);
        // completa/corta para o nº de colunas do cabeçalho
        rows.add(List.generate(cab.length, (k) => k < c.length ? c[k] : ''));
        i++;
      }
      out.add(Bloco.tabela(rows));
    } else {
      texto.add(linhas[i]);
      i++;
    }
  }
  fecharTexto();
  return out;
}

/// Widget que mostra o texto da IA já formatado (negrito, listas, quebras de linha e tabelas).
/// É um StatelessWidget: não guarda nada que muda, só desenha o que recebeu.
/// (veja GUIA_FLUTTER.md → StatelessWidget × StatefulWidget)
/// Texto da IA com negrito, listas, quebras de linha e tabelas.
class TextoFormatado extends StatelessWidget {
  const TextoFormatado(this.texto, {super.key, required this.estilo});

  // texto = o texto bruto (markdown simples) vindo da IA.
  final String texto;
  // estilo = fonte/cor base usada em tudo (a bolha escolhe a cor conforme o tema).
  final TextStyle estilo;

  /// Converte um pedaço de texto em um `TextSpan` (trecho de texto estilizado que pode ter
  /// "filhos" com estilos diferentes). Recebe o texto [t] e o estilo base [base].
  /// Passos: normaliza as listas (vira "•"), separa os negritos e cria um TextSpan por trecho;
  /// os trechos em negrito ganham `FontWeight.bold`, os outros herdam o estilo base (`null`).
  InlineSpan _span(String t, TextStyle? base) => TextSpan(
        style: base,
        children: [
          for (final p in parseNegrito(normalizarListas(t)))
            TextSpan(
              text: p.texto,
              style: p.negrito
                  ? const TextStyle(fontWeight: FontWeight.bold)
                  : null,
            ),
        ],
      );

  /// Monta a tela: uma coluna com um widget por bloco.
  /// Chamado pelo Flutter sempre que precisa desenhar este widget.
  @override
  Widget build(BuildContext context) {
    // (1) Quebra o texto em blocos (parágrafos e tabelas).
    final blocos = parseBlocos(texto);
    // Cor da borda da tabela: a cor do texto com 25% de opacidade (`withValues(alpha: 0.25)`);
    // `?.` só calcula se `estilo.color` não for nulo e `??` usa cinza como alternativa.
    final borda = estilo.color?.withValues(alpha: 0.25) ?? Colors.grey;
    // Column = empilha os blocos na vertical. `crossAxisAlignment.start` alinha à esquerda;
    // `mainAxisSize.min` faz a coluna ocupar só a altura necessária (não a tela toda).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // (2) `for` dentro da lista de filhos: cria um widget para cada bloco.
        for (final b in blocos)
          // Parágrafo comum: `Padding` dá 2 pixels de folga em cima e embaixo; `Text.rich` desenha
          // um texto composto por TextSpans (permite misturar negrito e normal na mesma frase).
          if (b.tabela == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text.rich(_span(b.texto, estilo)),
            )
          // Bloco de tabela: Padding de 6 em cima/embaixo para separar do texto ao redor.
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              // SingleChildScrollView com `scrollDirection: Axis.horizontal` = rolagem na horizontal.
              // Tabela larga rola para o lado em vez de estourar a bolha.
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                // Table = grade de linhas e colunas. `IntrinsicColumnWidth` faz cada coluna ter a largura
                // do seu maior conteúdo (em vez de dividir o espaço igualmente). `TableBorder.all` desenha
                // as linhas de grade em todas as células.
                child: Table(
                  defaultColumnWidth: const IntrinsicColumnWidth(),
                  border: TableBorder.all(color: borda, width: 0.8),
                  children: [
                    // Uma TableRow por linha da tabela (`b.tabela!` = tenho certeza de que não é nulo,
                    // pois este ramo só roda quando `b.tabela != null`).
                    for (var r = 0; r < b.tabela!.length; r++)
                      TableRow(
                        // Linha 0 (cabeçalho) ganha um fundo levemente colorido; as outras ficam sem fundo.
                        decoration: r == 0
                            ? BoxDecoration(color: borda.withValues(alpha: 0.2))
                            : null,
                        children: [
                          // Uma célula por texto: Padding interno de 8 na horizontal e 5 na vertical.
                          for (final c in b.tabela![r])
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 5),
                              // Texto da célula: 1 ponto menor que o normal (`(estilo.fontSize ?? 14) - 1`, com 14 como
                              // padrão se não houver tamanho) e em negrito se for o cabeçalho. Passa por `_span`, então
                              // negrito dentro da célula também funciona.
                              child: Text.rich(_span(
                                  c,
                                  estilo.copyWith(
                                      fontSize: (estilo.fontSize ?? 14) - 1,
                                      fontWeight: r == 0
                                          ? FontWeight.bold
                                          : null))),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
