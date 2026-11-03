import 'dart:convert';

import 'package:aurafarma_app/core/api_client.dart';
import 'package:aurafarma_app/core/sessao_storage.dart';
import 'package:aurafarma_app/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Medicamentos _med(String nome, String cod, String cat) => Medicamentos(
    nome: nome, codigo: cod, categorias: cat, quantidade: 1, preco: 1);

void main() {
  group('fromJson', () {
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

    test('request', () {
      final s = Solicitacao.fromJson(
          {'id': 'r1', 'name': 'Pomada', 'note': 'x', 'count': 2, 'date': '2026-03-05'});
      expect(s.pedidos, 2);
      expect(formatarDataIso(s.data), '05/03/2026');
    });

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

  group('filtrarMedicamentos', () {
    final lista = [
      _med('Dipirona', '111', 'Analgésico'),
      _med('Omeprazol', '222', 'Gástrico'),
      _med('Ácido fólico', '333', 'Vitamina'),
    ];

    test('sem acento e case-insensitive', () {
      expect(filtrarMedicamentos(lista, 'ACIDO').single.nome, 'Ácido fólico');
      expect(filtrarMedicamentos(lista, 'folico').length, 1);
    });
    test('por código', () {
      expect(filtrarMedicamentos(lista, '222').single.nome, 'Omeprazol');
    });
    test('por categoria', () {
      expect(filtrarMedicamentos(lista, '', categoria: 'Gástrico').length, 1);
      expect(filtrarMedicamentos(lista, 'dip', categoria: 'Gástrico'), isEmpty);
    });
    test('vazio devolve tudo', () {
      expect(filtrarMedicamentos(lista, '  ').length, 3);
    });
  });

  test('formatadores', () {
    expect(formatarPreco(12.5), 'R\$ 12,50');
    expect(formatarPreco(0), 'R\$ 0,00');
    expect(formatarData(DateTime(2026, 3, 5)), '05/03/2026');
    expect(formatarDataHora(DateTime(2026, 3, 5, 9, 7)), '05/03/2026 09:07');
  });

  group('ApiClient', () {
    test('extrai sid do set-cookie e reenvia', () async {
      final enviados = <String?>[];
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
      final storage = SessaoStorageMemoria();
      final api = ApiClient(client: client, storage: storage, baseUrl: 'http://x/api');

      expect(api.temSessao, isFalse);
      await api.post('/auth/login', {'identifier': 'a', 'password': 'b'});
      expect(api.temSessao, isTrue);
      expect(storage.valor, 'sid=abc123');

      await api.get('/estado');
      expect(enviados.last, 'sid=abc123');

      await api.limparSessao();
      expect(storage.valor, isNull);
    });

    test('erro do backend vira ApiException; rede vira status 0', () async {
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
      try {
        await api.get('/auth/me');
        fail('deveria lançar');
      } on ApiException catch (e) {
        expect(e.status, 401);
        expect(e.message, 'Credenciais inválidas');
        expect(e.details['password'], 'curta');
      }
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
