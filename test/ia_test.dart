// O QUE É ESTE ARQUIVO
// Testa as partes de TEXTO do assistente de IA: negrito, listas, tabelas e o histórico de conversas.
// Como rodar:  flutter test test/ia_test.dart
// Precisa de: nada (sem internet nem backend; só funções puras).
// Passou = respostas da IA (em markdown) viram texto/tabela corretamente e o histórico salva/carrega sem perder dados.
// Veja a seção 'Testes' do GUIA_FLUTTER.md.
//
import 'package:aurafarma_app/ia/conversa.dart';
import 'package:aurafarma_app/ia/texto_formatado.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // CENÁRIO: textos curtos com **negrito** (a IA responde em markdown, onde ** ** marca negrito) e listas com - ou *.
  // AÇÃO: chama parseNegrito (quebra o texto em pedaços 'normal' e 'negrito') e normalizarListas (troca - e * por bolinha).
  // CONFERIDO: os pedaços saem na ordem certa; um ** sem par ('**x') fica como texto comum em vez de quebrar a tela.
  // 'test(nome, função)' é um teste simples; 'expect(a, b)' confere se a é igual a b;
  // 'const Trecho(texto, negrito)' é um pedaço de texto com a marca de negrito.
  test('parser de negrito', () {
    expect(parseNegrito('a **b** c'), [
      const Trecho('a ', false),
      const Trecho('b', true),
      const Trecho(' c', false),
    ]);
    expect(parseNegrito('**x'), [const Trecho('**x', false)]);
    expect(normalizarListas('- um\n* dois'), '• um\n• dois');
  });

  // CENÁRIO: uma resposta da IA com texto, uma tabela markdown (linhas com | ) e mais texto.
  // AÇÃO: parseBlocos separa a resposta em blocos (texto, tabela, texto).
  // CONFERIDO: 3 blocos; a tabela virou lista de linhas/células e o texto antes e depois foi mantido. Casos de borda:
  // uma linha com barras soltas não é tabela, e linha curta ganha células vazias. Importa porque a tela desenha tabelas de verdade.
  test('tabela markdown vira bloco de tabela (e texto em volta é mantido)', () {
    // Texto de exemplo (strings coladas uma na outra; '\n' é quebra de linha).
    const md = 'Você tem **4 produtos**:\n\n'
        '| Produto | Estoque |\n|---|---|\n| Lenço | 3 |\n| Azitro | 4 |\n\n'
        'Precisam de reposição.';
    final b = parseBlocos(md);
    expect(b.length, 3);
    expect(b[0].texto, 'Você tem **4 produtos**:');
    expect(b[1].tabela, [
      ['Produto', 'Estoque'],
      ['Lenço', '3'],
      ['Azitro', '4'],
    ]);
    expect(b[2].texto, 'Precisam de reposição.');
    // barra solta sem separador não é tabela
    expect(parseBlocos('| só uma linha |').single.tabela, isNull);
    // linha curta é completada com células vazias
    expect(parseBlocos('| a | b |\n|---|---|\n| x |').single.tabela!.last,
        ['x', '']);
  });

  // CENÁRIO: uma conversa com 30 mensagens, uma mensagem de erro e uma mensagem gigante (5000 caracteres).
  // AÇÃO: monta o que seria enviado ao servidor (paraEnvio) e testa salvar/carregar o histórico
  // (codificar/decodificar = ida e volta em texto JSON).
  // CONFERIDO: só as 20 últimas vão, a gigante é cortada em 4000 caracteres, a mensagem de erro não é enviada, o histórico
  // volta igual e um texto inválido ('lixo') resulta em lista vazia, sem travar o app. Isso protege custo e limites da IA.
  test('conversa: serialização e truncamento', () {
    final c = ConversaIA(id: '1', titulo: 't');
    // Enche a conversa alternando falas do usuário ('user') e da IA ('assistant').
    for (var i = 0; i < 30; i++) {
      c.mensagens.add(MensagemIA(i.isEven ? 'user' : 'assistant', 'm$i'));
    }
    c.mensagens.add(const MensagemIA('assistant', 'falhou', erro: true));
    c.mensagens.add(MensagemIA('user', 'x' * 5000));
    // env = a lista de mensagens preparada para enviar ao servidor.
    final env = c.paraEnvio();
    expect(env.length, 20);
    expect(env.last['content']!.length, 4000);
    expect(env.any((m) => m['content'] == 'falhou'), isFalse);

    // Codifica a conversa para texto e decodifica de volta, como acontece ao fechar e reabrir o app.
    final lista = HistoricoIA.decodificar(HistoricoIA.codificar([c]));
    expect(lista.single.mensagens.length, c.mensagens.length);
    expect(lista.single.mensagens[30].erro, isTrue);
    expect(HistoricoIA.decodificar('lixo'), isEmpty);
  });
}
