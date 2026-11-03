// O QUE É ESTE ARQUIVO
// Testa os modelos de dados (models.dart), os filtros/formatadores e o ApiClient (cliente que fala com o servidor).
// Como rodar:  flutter test test/models_test.dart
// Precisa de: nada. A 'internet' é simulada (MockClient), então não precisa de backend.
// Passou = o app entende o JSON do servidor, filtra e formata certo e trata cookie/erro de rede. Falhou = algo disso quebrou.
// Veja a seção 'Testes' do GUIA_FLUTTER.md.
//
import 'dart:convert';

import 'package:aurafarma_app/core/api_client.dart';
import 'package:aurafarma_app/core/sessao_storage.dart';
import 'package:aurafarma_app/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Função auxiliar (não é teste): cria um Medicamentos rápido, só com nome, código e categoria,
// para as listas dos testes abaixo.
Medicamentos _med(String nome, String cod, String cat) => Medicamentos(
    nome: nome, codigo: cod, categorias: cat, quantidade: 1, preco: 1);

void main() {
  // 'group' agrupa testes parecidos só para a saída ficar organizada. 'test' e 'expect' são explicados nos outros arquivos de teste e no GUIA_FLUTTER.md.
  group('fromJson', () {
    // CENÁRIO: um produto como o servidor manda (JSON em inglês: sku, name, cat...).
    // AÇÃO: Medicamentos.fromJson converte o JSON em objeto do app.
    // CONFERIDO: os campos foram traduzidos (sku vira codigo, price vira preco), números inteiros viram decimais, e 'emBaixa' fica
    // verdadeiro quando estoque (3) <= mínimo (5). copyWith cria uma cópia com estoque 10, que já não está em baixa.
    test('product', () {
      final m = Medicamentos.fromJson({
        'id': 'p1', 'sku': '789', 'name': 'Dipirona', 'cat': 'Analgésico',
        'price': 12, 'cost': 5.5, 'stock': 3, 'min': 5,
      });
      expect(m.id, 'p1');
      expect(m.codigo, '789');
      expect(m.preco, 12.0);
      expect(m.custo, 5.5);
      expect(m.emBaixa, isTrue);
      expect(m.copyWith(quantidade: 10).emBaixa, isFalse);
    });

    // CENÁRIO: uma solicitação (cliente pediu um produto que a loja não tem).
    // AÇÃO/CONFERIDO: fromJson lê 'count' como pedidos e a data ISO vira 05/03/2026.
    test('request', () {
      final s = Solicitacao.fromJson(
          {'id': 'r1', 'name': 'Pomada', 'note': 'x', 'count': 2, 'date': '2026-03-05'});
      expect(s.pedidos, 2);
      expect(formatarDataIso(s.data), '05/03/2026');
    });

    // CENÁRIO: uma contagem de estoque com 2 ajustes (+2 e -1).
    // CONFERIDO: 2 ajustes lidos e a diferença total é a soma deles (1).
    test('count', () {
      final c = Contagem.fromJson({
        'id': 'c1',
        'ts': '2026-03-05T12:00:00.000Z',
        'adjustments': [
          {'pid': 'a', 'newStock': 5, 'diff': 2},
          {'pid': 'b', 'newStock': 1, 'diff': -1},
        ],
        'total': 2,
      });
      expect(c.ajustes.length, 2);
      expect(c.diferencaTotal, 1);
    });

    // CENÁRIO: resposta completa de /estado, com campos que o app mobile não usa (sales, activity).
    // CONFERIDO: o app lê produtos e 'populated' e ignora o resto sem quebrar; Estado.vazio começa não populado.
    test('estado ignora sales/activity', () {
      final e = Estado.fromJson({
        'populated': true,
        'products': [
          {'id': 'p1', 'sku': '1', 'name': 'A', 'cat': 'C', 'price': 1, 'cost': 1, 'stock': 1, 'min': 1}
        ],
        'sales': [{}],
        'requests': [],
        'counts': [],
        'activity': [{}],
      });
      expect(e.populado, isTrue);
      expect(e.produtos.length, 1);
      expect(Estado.vazio.populado, isFalse);
    });
  });

  // Testes da busca de medicamentos (filtrarMedicamentos) sobre uma lista de 3 produtos.
  group('filtrarMedicamentos', () {
    final lista = [
      _med('Dipirona', '111', 'Analgésico'),
      _med('Omeprazol', '222', 'Gástrico'),
      _med('Ácido fólico', '333', 'Vitamina'),
    ];

    // Busca 'ACIDO' acha 'Ácido fólico': ignora acento e maiúscula/minúscula, como o usuário digita.
    test('sem acento e case-insensitive', () {
      expect(filtrarMedicamentos(lista, 'ACIDO').single.nome, 'Ácido fólico');
      expect(filtrarMedicamentos(lista, 'folico').length, 1);
    });
    // Buscar pelo código de barras ('222') acha o Omeprazol.
    test('por código', () {
      expect(filtrarMedicamentos(lista, '222').single.nome, 'Omeprazol');
    });
    // Filtro por categoria, sozinho ou combinado com texto (texto que não bate com a categoria resulta em lista vazia).
    test('por categoria', () {
      expect(filtrarMedicamentos(lista, '', categoria: 'Gástrico').length, 1);
      expect(filtrarMedicamentos(lista, 'dip', categoria: 'Gástrico'), isEmpty);
    });
    // Busca só com espaços não filtra nada: devolve os 3 produtos.
    test('vazio devolve tudo', () {
      expect(filtrarMedicamentos(lista, '  ').length, 3);
    });
  });

  // Formatadores de preço e data: devem usar o padrão brasileiro (R$ 12,50 e 05/03/2026).
  // A barra antes do cifrão é só a forma de escrever um cifrão dentro de texto em Dart.
  test('formatadores', () {
    expect(formatarPreco(12.5), 'R\$ 12,50');
    expect(formatarPreco(0), 'R\$ 0,00');
    expect(formatarData(DateTime(2026, 3, 5)), '05/03/2026');
    expect(formatarDataHora(DateTime(2026, 3, 5, 9, 7)), '05/03/2026 09:07');
  });

  // Testes do ApiClient: o objeto que faz as chamadas HTTP ao backend e cuida do cookie de sessão.
  // MockClient (de package:http/testing.dart) é um 'cliente de internet de mentira': a gente define a resposta
  // que ele devolve, sem rede de verdade.
  group('ApiClient', () {
    // CENÁRIO: servidor falso que, no login, devolve um cookie 'sid=...' junto com outro cookie e uma data com vírgula.
    // AÇÃO: faz login, depois uma chamada qualquer (get /estado).
    // CONFERIDO: o app extrai só 'sid=abc123', guarda, reenvia no cabeçalho Cookie nas próximas chamadas e
    // apaga ao limpar a sessão. É assim que o app 'continua logado'.
    test('extrai sid do set-cookie e reenvia', () async {
      // Lista onde o servidor falso anota o cookie que recebeu em cada chamada.
      final enviados = <String?>[];
      // Servidor falso: responde ao login com cookie e a qualquer outra rota com {ok: true}.
      final client = MockClient((req) async {
        enviados.add(req.headers['Cookie']);
        if (req.url.path.endsWith('/auth/login')) {
          return http.Response(jsonEncode({'user': {}}), 200, headers: {
            'set-cookie':
                'sid=abc123; Path=/; HttpOnly; Expires=Wed, 21 Oct 2026 07:28:00 GMT, other=x',
            'content-type': 'application/json',
          });
        }
        return http.Response(jsonEncode({'ok': true}), 200);
      });
      // Armazenamento de sessão em memória (no app real fica no aparelho).
      final storage = SessaoStorageMemoria();
      // ApiClient montado com o servidor falso e o endereço de mentira.
      final api = ApiClient(client: client, storage: storage, baseUrl: 'http://x/api');

      // Antes do login não há sessão; depois do post, passa a haver.
      expect(api.temSessao, isFalse);
      await api.post('/auth/login', {'identifier': 'a', 'password': 'b'});
      expect(api.temSessao, isTrue);
      expect(storage.valor, 'sid=abc123');

      // Chamada seguinte: o cookie guardado tem que ter sido enviado.
      await api.get('/estado');
      expect(enviados.last, 'sid=abc123');

      // limparSessao (logout) apaga o cookie guardado.
      await api.limparSessao();
      expect(storage.valor, isNull);
    });

    // CENÁRIO: servidor falso que responde 401 com mensagem de erro, e uma rota que 'cai a rede' (lança exceção).
    // CONFERIDO: erro do servidor vira ApiException com status, mensagem e detalhes; falha de rede vira status 0
    // com mensagem amigável. Assim as telas sempre mostram uma mensagem clara em vez de travar.
    test('erro do backend vira ApiException; rede vira status 0', () async {
      // Servidor falso: '/boom' simula a rede caindo; qualquer outra rota responde 401.
      final api = ApiClient(
        client: MockClient((req) async {
          if (req.url.path.endsWith('/boom')) throw Exception('rede');
          return http.Response.bytes(
              utf8.encode(jsonEncode({'error': 'Credenciais inválidas', 'details': {'password': 'curta'}})),
              401);
        }),
        storage: SessaoStorageMemoria(),
        baseUrl: 'http://x/api',
      );
      // Caso 1: erro vindo do servidor. 'fail' faz o teste falhar se a chamada NÃO lançar erro (ela deveria).
      try {
        await api.get('/auth/me');
        fail('deveria lançar');
      } on ApiException catch (e) {
        expect(e.status, 401);
        expect(e.message, 'Credenciais inválidas');
        expect(e.details['password'], 'curta');
      }
      // Caso 2: falha de rede (status 0).
      try {
        await api.get('/boom');
        fail('deveria lançar');
      } on ApiException catch (e) {
        expect(e.status, 0);
        expect(e.message, 'Sem conexão com o servidor.');
      }
    });
  });
}
