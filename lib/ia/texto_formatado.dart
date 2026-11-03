import 'package:flutter/material.dart';

/// Pedaço de texto; [negrito] vem de `**x**`.
class Trecho {
  final String texto;
  final bool negrito;
  const Trecho(this.texto, this.negrito);

  @override
  bool operator ==(Object other) =>
      other is Trecho && other.texto == texto && other.negrito == negrito;

  @override
  int get hashCode => Object.hash(texto, negrito);
}

/// Separa `**negrito**` do texto comum (sem pacote de markdown).
/// Marcador sem fechamento é mantido como texto literal.
List<Trecho> parseNegrito(String s) {
  final out = <Trecho>[];
  final re = RegExp(r'\*\*(.+?)\*\*', dotAll: true);
  var i = 0;
  for (final m in re.allMatches(s)) {
    if (m.start > i) out.add(Trecho(s.substring(i, m.start), false));
    out.add(Trecho(m.group(1)!, true));
    i = m.end;
  }
  if (i < s.length) out.add(Trecho(s.substring(i), false));
  return out;
}

/// Itens de lista "- x" / "* x" viram "• x"; as quebras de linha são mantidas.
String normalizarListas(String s) => s
    .split('\n')
    .map((l) => l.replaceFirstMapped(
        RegExp(r'^(\s*)[-*]\s+'), (m) => '${m.group(1)}• '))
    .join('\n');

/// Bloco do texto: parágrafo comum ([tabela] nulo) ou tabela markdown.
class Bloco {
  final String texto;
  final List<List<String>>? tabela; // linha 0 = cabeçalho
  const Bloco.texto(this.texto) : tabela = null;
  const Bloco.tabela(List<List<String>> this.tabela) : texto = '';
}

bool _linhaDeTabela(String l) {
  final t = l.trim();
  return t.startsWith('|') && t.endsWith('|') && t.length > 1;
}

/// A linha de separação `|---|:---:|`.
bool _separador(String l) =>
    RegExp(r'^\|[\s:|-]+\|$').hasMatch(l.trim()) && l.contains('-');

List<String> _celulas(String l) {
  final t = l.trim();
  return t
      .substring(1, t.length - 1)
      .split('|')
      .map((c) => c.trim())
      .toList();
}

/// Separa tabelas markdown (`| a | b |` + `|---|---|`) do resto do texto.
List<Bloco> parseBlocos(String s) {
  final out = <Bloco>[];
  final texto = <String>[];
  final linhas = s.split('\n');
  void fecharTexto() {
    final t = texto.join('\n').trim();
    if (t.isNotEmpty) out.add(Bloco.texto(t));
    texto.clear();
  }

  var i = 0;
  while (i < linhas.length) {
    // tabela = cabeçalho + separador + 0..n linhas
    if (_linhaDeTabela(linhas[i]) &&
        i + 1 < linhas.length &&
        _separador(linhas[i + 1])) {
      fecharTexto();
      final cab = _celulas(linhas[i]);
      final rows = <List<String>>[cab];
      i += 2;
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

/// Texto da IA com negrito, listas, quebras de linha e tabelas.
class TextoFormatado extends StatelessWidget {
  const TextoFormatado(this.texto, {super.key, required this.estilo});

  final String texto;
  final TextStyle estilo;

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

  @override
  Widget build(BuildContext context) {
    final blocos = parseBlocos(texto);
    final borda = estilo.color?.withValues(alpha: 0.25) ?? Colors.grey;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final b in blocos)
          if (b.tabela == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text.rich(_span(b.texto, estilo)),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              // Tabela larga rola para o lado em vez de estourar a bolha.
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Table(
                  defaultColumnWidth: const IntrinsicColumnWidth(),
                  border: TableBorder.all(color: borda, width: 0.8),
                  children: [
                    for (var r = 0; r < b.tabela!.length; r++)
                      TableRow(
                        decoration: r == 0
                            ? BoxDecoration(color: borda.withValues(alpha: 0.2))
                            : null,
                        children: [
                          for (final c in b.tabela![r])
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 5),
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
