import 'package:aurafarma_app/ia/conversa.dart';
import 'package:aurafarma_app/ia/texto_formatado.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parser de negrito', () {
    expect(parseNegrito('a **b** c'), [
      const Trecho('a ', false),
      const Trecho('b', true),
      const Trecho(' c', false),
    ]);
    expect(parseNegrito('**x'), [const Trecho('**x', false)]);
    expect(normalizarListas('- um\n* dois'), '• um\n• dois');
  });

  test('tabela markdown vira bloco de tabela (e texto em volta é mantido)', () {
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

  test('conversa: serialização e truncamento', () {
    final c = ConversaIA(id: '1', titulo: 't');
    for (var i = 0; i < 30; i++) {
      c.mensagens.add(MensagemIA(i.isEven ? 'user' : 'assistant', 'm$i'));
    }
    c.mensagens.add(const MensagemIA('assistant', 'falhou', erro: true));
    c.mensagens.add(MensagemIA('user', 'x' * 5000));
    final env = c.paraEnvio();
    expect(env.length, 20);
    expect(env.last['content']!.length, 4000);
    expect(env.any((m) => m['content'] == 'falhou'), isFalse);

    final lista = HistoricoIA.decodificar(HistoricoIA.codificar([c]));
    expect(lista.single.mensagens.length, c.mensagens.length);
    expect(lista.single.mensagens[30].erro, isTrue);
    expect(HistoricoIA.decodificar('lixo'), isEmpty);
  });
}
